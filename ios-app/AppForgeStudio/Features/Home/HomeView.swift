import SwiftUI

/// INICIO — galería de proyectos (catálogo §5, era ❌: "sin galería, sin
/// persistencia visible"). Todo actuador tiene efecto real: crear abre un
/// documento nuevo, cada tarjeta abre su .appforge, duplicar/eliminar operan
/// sobre disco vía ProjectPersistenceService.
struct HomeView: View {
    /// Abrir un proyecto existente (URL) o crear uno nuevo (nil).
    let onOpen: (URL?) -> Void

    @State private var projects: [(url: URL, metadata: ProjectMetadata)] = []
    @State private var pendingDelete: URL?

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280),
                                    spacing: AppTheme.space3)]

    var body: some View {
        ZStack {
            AppTheme.bgCanvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.space4) {
                    header
                    LazyVGrid(columns: columns, spacing: AppTheme.space3) {
                        newProjectCard
                        ForEach(projects, id: \.url) { item in
                            projectCard(item)
                        }
                    }
                }
                .padding(AppTheme.space4)
            }
        }
        .onAppear(perform: reload)
        .alert("¿Eliminar proyecto?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Eliminar", role: .destructive) {
                if let url = pendingDelete {
                    try? ProjectPersistenceService.shared.deleteProject(at: url)
                    reload()
                }
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Se borrará del dispositivo. Esta acción no se puede deshacer.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AppForge Studio")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(AppTheme.textPrimaryColor)
            Text(projects.isEmpty
                 ? "Crea tu primer proyecto — CAD paramétrico + escultura en un solo lugar"
                 : "\(projects.count) proyecto\(projects.count == 1 ? "" : "s")")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondaryColor)
        }
        .padding(.top, AppTheme.space4)
    }

    private var newProjectCard: some View {
        Button {
            HapticService.shared.medium()
            onOpen(nil)
        } label: {
            VStack(spacing: AppTheme.space2) {
                Image(systemName: "plus")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(AppTheme.accentColor)
                Text("Nuevo proyecto")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimaryColor)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusLG)
                    .strokeBorder(AppTheme.accentColor.opacity(0.55),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.newProject")
    }

    private func projectCard(_ item: (url: URL, metadata: ProjectMetadata)) -> some View {
        Button {
            HapticService.shared.light()
            onOpen(item.url)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Zona visual: identidad geométrica del documento
                ZStack {
                    LinearGradient(colors: [AppTheme.accentColor.opacity(0.16),
                                            Color.black.opacity(0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 38, weight: .ultraLight))
                        .foregroundColor(AppTheme.accentColor.opacity(0.9))
                }
                .frame(height: 96)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.metadata.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimaryColor)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(item.metadata.modelCount) cuerpo\(item.metadata.modelCount == 1 ? "" : "s")")
                        Text("·")
                        Text(item.metadata.modifiedAt, style: .relative)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondaryColor)
                }
                .padding(10)
            }
            .background(Color.white.opacity(0.045))
            .cornerRadius(AppTheme.radiusLG)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onOpen(item.url)
            } label: { Label("Abrir", systemImage: "folder") }
            Button {
                try? ProjectPersistenceService.shared.duplicateProject(at: item.url)
                reload()
            } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
            Button(role: .destructive) {
                pendingDelete = item.url
            } label: { Label("Eliminar", systemImage: "trash") }
        }
    }

    private func reload() {
        projects = ProjectPersistenceService.shared.listProjects()
    }
}
