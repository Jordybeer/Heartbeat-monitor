import SwiftUI
import HeartbeatCore

struct SettingsView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var confirmDelete = false
    @State private var showHealth = false
    var body: some View {
        Form {
            Section {
                Toggle("Automatisch starten", isOn: $model.settings.autoStart)
            } footer: { Text("Probeert de dagelijkse sensorverbinding automatisch te starten bij het openen of herstellen van de app. Start na wegvegen, herstarten of in-ear-detectie is niet gegarandeerd. Stop onderbreekt automatisch starten tot je zelf hervat.") }

            Section("Hartslagmelding") {
                Toggle("Melding bij overschrijding", isOn: Binding(get: { model.settings.threshold.enabled }, set: { value in
                    if value { Task { await model.enableNotifications() } } else { model.settings.threshold.enabled = false }
                }))
                Stepper("Grens: \(Int(model.settings.threshold.bpm)) BPM", value: $model.settings.threshold.bpm, in: 40...250, step: 1)
                Picker("Overschrijding aanhouden", selection: $model.settings.threshold.duration) {
                    Text("Direct").tag(0.0); Text("10 seconden").tag(10.0); Text("30 seconden").tag(30.0); Text("1 minuut").tag(60.0); Text("2 minuten").tag(120.0)
                }
                Stepper("Opnieuw na \(Int(model.settings.threshold.rearmMargin)) BPM daling onder de grens", value: $model.settings.threshold.rearmMargin, in: 0...20, step: 1)
                Text("Alleen verse metingen tellen. Je krijgt één melding per overschrijding; pas na voldoende daling kan er een nieuwe volgen. iOS bepaalt de weergave en het geluid.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Toegangsscherm") {
                Toggle("Verberg BPM op toegangsscherm", isOn: $model.settings.hideBPM)
                Text("Deze keuze verbergt ook de BPM in nieuwe meldingen. De Live Activity toont wanneer een meting verouderd is.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Apple Gezondheid") {
                Button { showHealth = true } label: { Label("Bekijk de laatste 24 uur", systemImage: "heart.text.clipboard") }
                Text("Bestaande hartslagdata wordt apart gelezen. Alleen work-outs die je zelf start worden door deze app in Gezondheid opgeslagen; dagelijkse Bluetooth-metingen blijven lokaal.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Meetlog") {
                Picker("Bewaren", selection: $model.settings.retentionDays) { Text("7 dagen").tag(7); Text("30 dagen").tag(30); Text("90 dagen").tag(90); Text("Onbeperkt").tag(0) }
                Button("Verwijder lokale meetgeschiedenis", role: .destructive) { confirmDelete = true }.disabled(model.isRequested || model.isStopping)
                Text("Verwijderen raakt geen gegevens in Apple Gezondheid. Je kunt een sessie als CSV delen vanuit Geschiedenis.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Open iOS-instellingen") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                LabeledContent("Versie", value: "1.0 · experimenteel")
                Text("Heartbeat toont gemeten waarden en is geen diagnose- of noodalarmsysteem. Beschikbaarheid van data zegt niets over klinische nauwkeurigheid.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Instellingen")
        .confirmationDialog("Alle lokale sessies en meetpunten verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijder meetgeschiedenis", role: .destructive) { Task { await model.deleteHistory() } }
        }
        .sheet(isPresented: $showHealth) { HealthHistoryView().environmentObject(model) }
    }
}

struct HealthHistoryView: View {
    @EnvironmentObject private var model: MonitorModel
    @Environment(\.dismiss) private var dismiss
    @State private var samples: [HeartRateSample] = []
    @State private var isLoading = true
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading { ProgressView("Gegevens ophalen…").padding(40) }
                    else if let error { ContentUnavailableView("Gegevens niet beschikbaar", systemImage: "heart.slash", description: Text(error)) }
                    else if samples.isEmpty { ContentUnavailableView("Geen leesbare metingen", systemImage: "heart.text.clipboard", description: Text("Er zijn geen beschikbare metingen in de afgelopen 24 uur. Controleer eventueel je toegang in Apple Gezondheid.")) }
                    else {
                        Surface { VStack(spacing: 20) { HeartRateChart(samples: samples, height: 240); StatisticsRow(samples: samples) } }
                        Surface { VStack(alignment: .leading, spacing: 8) { Text("Bronnen").font(.headline); ForEach(Array(Set(samples.map(\.source))).sorted(), id: \.self) { Text($0).font(.subheadline).foregroundStyle(.secondary) } } }
                    }
                    Text("Deze gegevens komen uit Apple Gezondheid en activeren geen meldingen achteraf. Ze worden niet aan je lokale sessies toegevoegd.").font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }.background(Palette.background).navigationTitle("Gezondheid · 24 uur").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gereed") { dismiss() } } }
                .task {
                    do { samples = try await model.health.history() } catch { self.error = error.localizedDescription }
                    isLoading = false
                }
        }
    }
}
