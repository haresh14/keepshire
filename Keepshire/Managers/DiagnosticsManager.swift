import Foundation
import MetricKit

final class DiagnosticsManager: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsManager()
    static let lastDiagnosticDateKey = "lastMetricKitDiagnosticDate"

    private let defaults: UserDefaults

    /// Only the shared instance subscribes, and it lives as long as the app. MetricKit removes
    /// a subscriber later on its own queue, so unsubscribing from `deinit` touches freed memory.
    private override convenience init() {
        self.init(defaults: .standard)
        MXMetricManager.shared.add(self)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        super.init()
    }

    var lastDiagnosticDate: Date? {
        defaults.object(forKey: Self.lastDiagnosticDateKey) as? Date
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        guard !payloads.isEmpty else { return }
        VaultLog.debug("MetricKit delivered an aggregated metric payload")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard !payloads.isEmpty else { return }
        recordDiagnosticDelivery()
    }

    func recordDiagnosticDelivery(at date: Date = Date()) {
        defaults.set(date, forKey: Self.lastDiagnosticDateKey)
        VaultLog.error("MetricKit delivered a crash or hang diagnostic")
    }
}
