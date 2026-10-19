import AppIntents
import ActivityKit
import Foundation

struct StopMonitoringIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Hartslagmeting stoppen"
    static var description = IntentDescription("Stopt Heartbeat en onderbreekt automatisch starten tot je zelf hervat.")
    func perform() async throws -> some IntentResult {
        #if HEARTBEAT_APP
        UserDefaults.standard.set(true, forKey: "manualStop")
        await MonitorModel.shared.stop()
        #else
        for activity in Activity<HeartbeatAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        #endif
        return .result()
    }
}
