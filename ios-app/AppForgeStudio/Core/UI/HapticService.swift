import UIKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "HapticService")
final class HapticService {
    static let shared = HapticService()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
    }

    func light() {
        lightGenerator.impactOccurred()
    }

    func medium() {
        mediumGenerator.impactOccurred()
    }

    func heavy() {
        heavyGenerator.impactOccurred()
    }

    func selection() {
        selectionGenerator.selectionChanged()
    }
}
