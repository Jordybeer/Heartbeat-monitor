import SwiftUI
import WidgetKit
import ActivityKit

@main
struct HeartbeatWidgets: WidgetBundle {
    var body: some Widget { HeartbeatLiveActivity() }
}
struct HeartbeatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HeartbeatAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "heart.fill").font(.title).foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(value(context)).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                        if !context.state.hideBPM { Text("BPM").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(context.isStale ? "Geen actuele meting" : context.state.message).font(.caption).lineLimit(1)
                    Text(context.state.updatedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(intent: StopMonitoringIntent()) { Image(systemName: "stop.fill").padding(12) }.buttonStyle(.bordered)
                    .accessibilityLabel("Meting stoppen")
            }.padding(18).activityBackgroundTint(Color(.secondarySystemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Heartbeat", systemImage: "heart.fill").foregroundStyle(.pink).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { Text(value(context)).font(.title2.bold()).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(context.isStale ? "Geen actuele meting" : context.state.message).font(.caption)
                            Text(context.attributes.startedAt, style: .timer).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Stop", intent: StopMonitoringIntent()).buttonStyle(.bordered)
                    }
                }
            } compactLeading: {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            } compactTrailing: {
                Text(value(context)).monospacedDigit().font(.caption.bold())
            } minimal: {
                Image(systemName: context.isStale ? "heart.slash" : "heart.fill").foregroundStyle(.pink)
            }.keylineTint(.pink)
        }
    }
    private func value(_ context: ActivityViewContext<HeartbeatAttributes>) -> String {
        if context.state.hideBPM { return "Actief" }
        return context.isStale ? "—" : context.state.bpm.map(String.init) ?? "—"
    }
}
