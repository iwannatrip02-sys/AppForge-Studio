import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "PreferencesView")
struct PreferencesView: View {
    @AppStorage("renderQuality") private var renderQuality: RenderQuality = .high
    @AppStorage("showGrid") private var showGrid = true
    @AppStorage("gridSize") private var gridSize: Float = 1.0
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 300
    @AppStorage("defaultExportFormat") private var defaultExportFormat: PreferencesExportFormat = .stl
    @AppStorage("theme") private var theme: PreferencesAppTheme = .system
    @AppStorage("undoLimit") private var undoLimit: Double = 50
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Render Section
                Section("Render") {
                    Picker("Quality", selection: $renderQuality) {
                        ForEach(RenderQuality.allCases) { q in
                            Text(q.label).tag(q)
                        }
                    }
                    Toggle("Show Grid", isOn: $showGrid)
                    if showGrid {
                        HStack {
                            Text("Grid Size")
                            Slider(value: $gridSize, in: 0.1...10, step: 0.1)
                            Text(String(format: "%.1f", gridSize))
                                .font(.caption.monospaced())
                                .frame(width: 40)
                        }
                    }
                }
                
                // MARK: - File Section
                Section("File") {
                    Toggle("Auto-Save", isOn: $autoSave)
                    if autoSave {
                        HStack {
                            Text("Interval (s)")
                            Slider(value: $autoSaveInterval, in: 30...600, step: 30)
                            Text("\(Int(autoSaveInterval))s")
                                .font(.caption.monospaced())
                                .frame(width: 50)
                        }
                    }
                    Picker("Default Export", selection: $defaultExportFormat) {
                        ForEach(PreferencesExportFormat.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                }
                
                // MARK: - Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        ForEach(PreferencesAppTheme.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                }
                
                // MARK: - Advanced Section
                Section("Advanced") {
                    HStack {
                        Text("Undo Limit")
                        Slider(value: $undoLimit, in: 10...200, step: 10)
                        Text("\(Int(undoLimit))")
                            .font(.caption.monospaced())
                            .frame(width: 40)
                    }
                }
            }
            .navigationTitle("Preferences")
        }
    }
}

// MARK: - Enums

enum RenderQuality: String, CaseIterable, Identifiable {
    case low, medium, high, ultra
    var id: String { rawValue }
    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        case .ultra:  return "Ultra"
        }
    }
}

enum PreferencesExportFormat: String, CaseIterable, Identifiable {
    case stl, obj, usdz, gltf, fbx
    var id: String { rawValue }
    var label: String {
        switch self {
        case .stl:  return "STL"
        case .obj:  return "OBJ"
        case .usdz: return "USDZ"
        case .gltf: return "glTF"
        case .fbx:  return "FBX"
        }
    }
}

enum PreferencesAppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
