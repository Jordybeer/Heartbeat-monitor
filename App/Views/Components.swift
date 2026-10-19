import SwiftUI
import Charts
import HeartbeatCore

enum Palette {
    static let accent = Color(red: 0.94, green: 0.25, blue: 0.34)
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
}
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 24)) }
}
struct HeartRateChart: View {
    let samples: [HeartRateSample]
    var threshold: Double? = nil
    var height: CGFloat = 190
    @State private var selectedDate: Date?
    private var segments: [[HeartRateSample]] { ChartSegments.split(samples) }
    private var selected: HeartRateSample? {
        guard let selectedDate else { return nil }
        return samples.min { abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selected {
                HStack {
                    Text("\(Int(selected.bpm)) BPM").bold().monospacedDigit()
                    Spacer()
                    Text(selected.timestamp, format: .dateTime.hour().minute().second()).foregroundStyle(.secondary)
                }.font(.caption)
            }
            if samples.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line").font(.largeTitle.weight(.light)).foregroundStyle(.tertiary)
                    Text("Je tijdlijn begint bij de eerste meting.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).frame(height: height)
            } else {
                Chart {
                    ForEach(Array(segments.enumerated()), id: \.offset) { segment in
                        ForEach(segment.element) { sample in
                            LineMark(x: .value("Tijd", sample.timestamp), y: .value("BPM", sample.bpm), series: .value("Reeks", segment.offset))
                                .foregroundStyle(Palette.accent).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            if segment.element.count == 1 {
                                PointMark(x: .value("Tijd", sample.timestamp), y: .value("BPM", sample.bpm)).foregroundStyle(Palette.accent)
                            }
                        }
                    }
                    if let threshold { RuleMark(y: .value("Jouw grens", threshold)).foregroundStyle(.secondary.opacity(0.6)).lineStyle(StrokeStyle(dash: [4, 5])).annotation(position: .top, alignment: .trailing) { Text("Grens").font(.caption2).foregroundStyle(.secondary) } }
                    if let selected { RuleMark(x: .value("Geselecteerd", selected.timestamp)).foregroundStyle(.secondary.opacity(0.4)) }
                }
                .chartXSelection(value: $selectedDate)
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in AxisGridLine().foregroundStyle(.gray.opacity(0.12)); AxisValueLabel() } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.hour().minute()) } }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: height)
                .accessibilityLabel("Hartslaggrafiek, \(samples.count) metingen")
                .accessibilityValue("Minimum \(Int(samples.map(\.bpm).min() ?? 0)), maximum \(Int(samples.map(\.bpm).max() ?? 0)) BPM")
            }
        }
    }
}
struct StatisticsRow: View {
    let samples: [HeartRateSample]
    var body: some View {
        let values = samples.map(\.bpm)
        HStack {
            metric("LAAGSTE", values.min())
            Spacer()
            metric("GEMIDDELD", values.isEmpty ? nil : values.reduce(0, +) / Double(values.count))
            Spacer()
            metric("HOOGSTE", values.max())
        }
    }
    private func metric(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary)
            Text(value.map { String(Int($0.rounded())) } ?? "—").font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}
struct InfoRow: View {
    var icon: String
    var title: String
    var text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Palette.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(text).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}
