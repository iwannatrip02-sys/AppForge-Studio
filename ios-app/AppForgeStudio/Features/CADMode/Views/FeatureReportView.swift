import SwiftUI

/// Hoja de reporte de features de fabricación reconocidas desde el B-rep.
///
/// Muestra el resumen (agujeros y cajeras) del último análisis de
/// `FeatureReportController`. Se presenta como sheet — la única forma de
/// modal permitida por el doc de diseño para flujos de "análisis/export".
struct FeatureReportView: View {
    @ObservedObject var controller: FeatureReportController
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        NavigationView {
            Group {
                if let report = controller.report {
                    reportContent(report)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "wand.and.rays.inverse")
                            .font(.system(size: 36))
                            .foregroundColor(theme.textSecondary)
                        Text(controller.statusMessage)
                            .font(.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
                }
            }
            .navigationTitle("Features reconocidas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Contenido del reporte

    @ViewBuilder
    private func reportContent(_ report: FeatureRecognitionService.Report) -> some View {
        List {
            // Resumen general
            Section {
                HStack {
                    Image(systemName: report.isEmpty ? "checkmark.circle" : "chart.bar.doc.horizontal")
                        .foregroundColor(report.isEmpty ? theme.textSecondary : theme.accent)
                    Text(report.summary)
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                }
            } header: {
                Text("Resumen")
            }

            // Agujeros cilíndricos
            if !report.holes.isEmpty {
                Section {
                    ForEach(report.holes) { hole in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "Ø %.2f mm", hole.diameter))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(String(format: "Profundidad: %.2f mm", hole.depth))
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Label("Agujeros (\(report.holes.count))", systemImage: "circle.dashed")
                }
            }

            // Cajeras
            if !report.pockets.isEmpty {
                Section {
                    ForEach(report.pockets) { pocket in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "Profundidad: %.2f mm", pocket.depth))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(pocket.isOpen ? "Cajera abierta (ranura)" : "Cajera cerrada (bolsillo)")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Label("Cajeras (\(report.pockets.count))", systemImage: "square.on.square.dashed")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
