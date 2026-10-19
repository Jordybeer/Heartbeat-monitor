import ActivityKit
import Foundation
import HeartbeatCore

@MainActor
final class LiveActivityService {
    private var activity: Activity<HeartbeatAttributes>?
    private var updateTask: Task<Void, Never>?
    private var lastPublished = Date.distantPast
    func begin(mode: String, hideBPM: Bool) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let activity, activity.activityState == .ended || activity.activityState == .dismissed { self.activity = nil }
        guard activity == nil else { return }
        let state = HeartbeatAttributes.ContentState(bpm: nil, updatedAt: Date(), message: "Wachten op meting", hideBPM: hideBPM)
        activity = try Activity.request(attributes: .init(startedAt: Date(), mode: mode), content: .init(state: state, staleDate: Date().addingTimeInterval(15)), pushType: nil)
    }
    func update(_ sample: HeartRateSample?, message: String, hideBPM: Bool, force: Bool = false) {
        guard let activity else { return }
        guard force || Date().timeIntervalSince(lastPublished) >= 5 else { return }
        lastPublished = Date(); updateTask?.cancel()
        let state = HeartbeatAttributes.ContentState(bpm: sample.map { Int($0.bpm.rounded()) }, updatedAt: sample?.timestamp ?? Date(), message: message, hideBPM: hideBPM)
        let stale = sample?.timestamp.addingTimeInterval(15) ?? Date().addingTimeInterval(15)
        updateTask = Task { await activity.update(.init(state: state, staleDate: stale)) }
    }
    func end() async {
        updateTask?.cancel(); updateTask = nil; activity = nil; lastPublished = .distantPast
        for existing in Activity<HeartbeatAttributes>.activities { await existing.end(nil, dismissalPolicy: .immediate) }
    }
}
