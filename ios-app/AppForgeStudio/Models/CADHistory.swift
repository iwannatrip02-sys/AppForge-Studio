import Foundation

// MARK: - CAD History Entry

struct CADHistoryEntry: Identifiable, Codable {
    let id: UUID
    var operationType: String
    var description: String
    var affectedModelIDs: [String]
    var timestamp: Date
    var parameters: [String: Double]
    
    init(id: UUID = UUID(), operationType: String, description: String,
         affectedModelIDs: [String] = [], parameters: [String: Double] = [:]) {
        self.id = id
        self.operationType = operationType
        self.description = description
        self.affectedModelIDs = affectedModelIDs
        self.timestamp = Date()
        self.parameters = parameters
    }
}

// MARK: - CAD History Manager

class CADHistoryManager: ObservableObject {
    @Published var entries: [CADHistoryEntry] = []
    @Published var currentIndex: Int = -1
    @Published var isDirty: Bool = false
    
    private let storageKey = "cad_history"
    private let maxEntries = 100
    
    init() {
        loadFromDisk()
    }
    
    // MARK: - Record
    
    func record(_ entry: CADHistoryEntry) {
        if currentIndex < entries.count - 1 {
            entries = Array(entries.prefix(currentIndex + 1))
        }
        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
        currentIndex = entries.count - 1
        isDirty = true
        saveToDisk()
    }
    
    // MARK: - Undo
    
    func undo() -> CADHistoryEntry? {
        guard currentIndex >= 0 else { return nil }
        let entry = entries[currentIndex]
        currentIndex -= 1
        isDirty = true
        return entry
    }
    
    // MARK: - Redo
    
    func redo() -> CADHistoryEntry? {
        guard currentIndex + 1 < entries.count else { return nil }
        currentIndex += 1
        isDirty = true
        return entries[currentIndex]
    }
    
    // MARK: - State
    
    var canUndo: Bool { currentIndex >= 0 }
    var canRedo: Bool { currentIndex + 1 < entries.count }
    
    func clear() {
        entries.removeAll()
        currentIndex = -1
        isDirty = false
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    func saveToDisk() {
        guard let data = serialize() else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = deserialize(from: data) {
            entries = decoded
            currentIndex = entries.count - 1
        }
    }
    
    func serialize() -> Data? {
        try? JSONEncoder().encode(entries)
    }
    
    func deserialize(from data: Data) -> [CADHistoryEntry]? {
        try? JSONDecoder().decode([CADHistoryEntry].self, from: data)
    }
    
    func exportJSON() -> String {
        guard let data = serialize(),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}

// MARK: - Factory helpers

extension CADHistoryEntry {
    static func createShape(_ name: String) -> CADHistoryEntry {
        CADHistoryEntry(operationType: "createShape", description: "Crear \(name)")
    }
    
    static func extrude(_ name: String, distance: Double) -> CADHistoryEntry {
        CADHistoryEntry(operationType: "extrude", description: "Extruir \(name)",
                       parameters: ["distance": distance])
    }
    
    static func booleanOp(_ type: String, target: String, tool: String) -> CADHistoryEntry {
        CADHistoryEntry(operationType: "boolean\(type)",
                       description: "\(type) \(target) con \(tool)")
    }
    
    static func deleteModel(_ name: String) -> CADHistoryEntry {
        CADHistoryEntry(operationType: "delete", description: "Eliminar \(name)")
    }
}