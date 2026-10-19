import SwiftUI
import HeartbeatCore

struct HistoryView: View {
    @EnvironmentObject private var model: MonitorModel
    var body: some View {
        Group {
            if model.sessions.isEmpty {
                ContentUnavailableView("Nog geen meetlog", systemImage: "clock", description: Text("Zodra je echte metingen ontvangt, vind je de sessies hier terug."))
            } else {
                List(model.sessions) { session in
                    NavigationLink { SessionDetailView(session: session) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: session.mode == "daily" ? "heart" : "figure.walk").foregroundStyle(Palette.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.startedAt, format: .dateTime.day().month(.wide).hour().minute()).font(.headline)
                                Text("\(session.count) metingen · \(session.mode == "daily" ? "Dagelijks" : "Work-out")").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(session.average.map { String(Int($0.rounded())) } ?? "—").font(.title3.weight(.semibold)).monospacedDigit()
                                Text("gem. BPM").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8)
                    }
                }.listStyle(.insetGrouped)
            }
        }.navigationTitle("Geschiedenis").task { await model.refreshHistory() }.refreshable { await model.refreshHistory() }
    }
}

struct SessionDetailView: View {
    let session: SessionSummary
    @EnvironmentObject private var model: MonitorModel
    @State private var samples: [HeartRateSample] = []
    @State private var events: [StoredEvent] = []
    @State private var csvURL: URL?
    @State private var failure: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(session.startedAt, format: .dateTime.day().month(.wide).year().hour().minute()).font(.headline)
                        HeartRateChart(samples: samples, height: 230)
                        StatisticsRow(samples: samples)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sessielog").font(.headline)
                        LabeledContent("Metingen", value: String(samples.count))
                        LabeledContent("Status", value: session.endedAt == nil ? "Actief / nog niet afgesloten" : session.reason)
                        if let first = samples.first, let last = samples.last {
                            LabeledContent("Eerste meting", value: first.timestamp.formatted(date: .omitted, time: .standard))
                            LabeledContent("Laatste meting", value: last.timestamp.formatted(date: .omitted, time: .standard))
                        }
                        ForEach(events) { event in
                            HStack(alignment: .top) { Text(event.date, format: .dateTime.hour().minute().second()).monospacedDigit(); Text(event.text) }.font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let csvURL { ShareLink(item: csvURL) { Label("Deel meetlog als CSV", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(8) }.buttonStyle(.bordered) }
                if let failure { Text(failure).font(.footnote).foregroundStyle(.red) }
                Text("Een leeg stuk in de grafiek betekent ontbrekende data. Tijdstempels in CSV zijn in UTC; de app toont je lokale tijd.").font(.footnote).foregroundStyle(.secondary)
            }.padding(20)
        }.background(Palette.background).navigationTitle("Sessie").navigationBarTitleDisplayMode(.inline)
            .task {
                do {
                    samples = try await model.store?.samples(for: session.id) ?? []
                    events = try await model.store?.events(for: session.id) ?? []
                    let file = FileManager.default.temporaryDirectory.appendingPathComponent("heartbeat-\(session.id.uuidString).csv")
                    try CSVExport.render(samples).write(to: file, atomically: true, encoding: .utf8)
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
                    csvURL = file
                } catch { failure = "Meetlog niet beschikbaar: \(error.localizedDescription)" }
            }
    }
}
