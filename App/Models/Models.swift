import Foundation
import HealthKit
import HeartbeatCore

enum MonitoringMode: String, Codable, CaseIterable, Identifiable {
    case daily, workout
    var id: String { rawValue }
    var title: String { self == .daily ? "Dagelijks · experimenteel" : "Work-out · HealthKit" }
}
enum WorkoutChoice: String, Codable, CaseIterable, Identifiable {
    case walking, running, cycling
    var id: String { rawValue }
    var title: String { switch self { case .walking: "Wandelen"; case .running: "Hardlopen"; case .cycling: "Fietsen" } }
    var activity: HKWorkoutActivityType { switch self { case .walking: .walking; case .running: .running; case .cycling: .cycling } }
}
struct MonitorSettings: Codable, Equatable {
    var autoStart = true
    var hideBPM = false
    var retentionDays = 30
    var mode = MonitoringMode.daily
    var workout = WorkoutChoice.walking
    var threshold = ThresholdRule()
    static let key = "heartbeat.settings.v1"
    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: key), let settings = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        return settings
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) } }
}
struct SessionSummary: Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var mode: String
    var reason: String
    var count: Int
    var average: Double?
    var minimum: Double?
    var maximum: Double?
}
struct StoredEvent: Identifiable, Sendable {
    var id: UUID
    var date: Date
    var text: String
}
struct SensorDevice: Identifiable, Equatable {
    var id: UUID
    var name: String
}
