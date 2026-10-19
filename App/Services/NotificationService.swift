import UserNotifications
import Foundation
import HeartbeatCore

enum NotificationService {
    static func request() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
    static func send(_ trigger: ThresholdTrigger, hideBPM: Bool) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Ingestelde hartslaggrens overschreden"
        content.body = hideBPM ? "Open Heartbeat om de meting te bekijken." : "\(Int(trigger.bpm.rounded())) BPM · jouw grens is \(Int(trigger.threshold)) BPM."
        content.sound = .default
        content.userInfo = ["screen": "monitor"]
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
