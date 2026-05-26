import Foundation
import OSLog

// MARK: - CrashReporting Protocol
protocol CrashReporting {
    func logError(_ error: Error)
    func logEvent(_ name: String, metadata: [String: Any]?)
    func logMetric(_ name: String, value: Double, unit: String?)
}

extension CrashReporting {
    func logEvent(_ name: String) {
        logEvent(name, metadata: nil)
    }
    func logMetric(_ name: String, value: Double) {
        logMetric(name, value: value, unit: nil)
    }
}

// MARK: - FirebaseCrashlytics Implementation
final class FirebaseCrashlytics: CrashReporting {
    private let logger = Logger(subsystem: "com.appforgestudio", category: "FirebaseCrashlytics")

    func logError(_ error: Error) {
        logger.error("Crashlytics error: \(error.localizedDescription)")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
        #endif
    }

    func logEvent(_ name: String, metadata: [String: Any]?) {
        logger.log("Crashlytics event: \(name)")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("Event: \(name)")
        if let metadata = metadata {
            Crashlytics.crashlytics().setCustomKeys(metadata)
        }
        #endif
    }

    func logMetric(_ name: String, value: Double, unit: String?) {
        logger.log("Crashlytics metric: \(name) = \(value)")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: name)
        #endif
    }
}

// MARK: - Logger Extension
extension Logger {
    func report(error: Error) {
        self.error("\(error.localizedDescription)")
    }

    func report(event: String, metadata: [String: Any]? = nil) {
        self.log("Event: \(event)")
    }

    func report(metric: String, value: Double) {
        self.log("Metric: \(metric) = \(value)")
    }
}
