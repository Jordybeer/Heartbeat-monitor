import ActivityKit
import Foundation

struct HeartbeatAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bpm: Int?
        var updatedAt: Date
        var message: String
        var hideBPM: Bool
    }
    var startedAt: Date
    var mode: String
}
