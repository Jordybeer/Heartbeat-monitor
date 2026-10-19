import SwiftUI
import HeartbeatCore

struct RootView: View {
    @EnvironmentObject private var model: MonitorModel
    var body: some View {
        TabView {
            Tab("Nu", systemImage: "heart.fill") { NavigationStack { MonitorView() } }
            Tab("Geschiedenis", systemImage: "clock") { NavigationStack { HistoryView() } }
            Tab("Instellingen", systemImage: "slider.horizontal.3") { NavigationStack { SettingsView() } }
        }
        .alert("Heartbeat", isPresented: Binding(get: { model.lastError != nil }, set: { if !$0 { model.lastError = nil } })) {
            Button("OK", role: .cancel) { model.lastError = nil }
        } message: { Text(model.lastError ?? "") }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var model: MonitorModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Image(systemName: "heart.fill").font(.system(size: 58)).foregroundStyle(Palette.accent).padding(.top, 36)
                Text("Je hartslag.\nIn beeld.").font(.system(size: 42, weight: .bold, design: .rounded)).tracking(-1.5)
                Text("Volg je metingen met AirPods Pro 3, zonder drukte op je scherm.").font(.title3).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 24) {
                    InfoRow(icon: "waveform.path", title: "Een levende tijdlijn", text: "Echte metingen met tijdstempels. Ontbrekende data blijft zichtbaar.")
                    InfoRow(icon: "bell.badge", title: "Jouw grens", text: "Kies zelf wanneer je een hartslagmelding wilt ontvangen.")
                    InfoRow(icon: "lock", title: "Op jouw iPhone", text: "Je meetlog blijft lokaal. Jij kiest wat je deelt.")
                }
                Toggle("Automatisch starten bij AirPods-gebruik", isOn: $model.settings.autoStart).font(.subheadline)
                Text("Dagelijkse meting en automatisch verbinden zijn experimenteel. Ze werken alleen als de AirPods hun hartslag via de beschikbare verbinding leveren. Een work-out start je altijd zelf.").font(.footnote).foregroundStyle(.secondary)
                Button { model.completeOnboarding() } label: { Text("Beginnen").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10) }.buttonStyle(.borderedProminent).controlSize(.large)
            }.padding(28)
        }.background(Palette.background)
    }
}

struct MonitorView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var window = 15
    @State private var showSensors = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let latest = model.samples.last
            let fresh = model.isRequested ? latest.flatMap { $0.isFresh(at: timeline.date) ? $0 : nil } : nil
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        HStack(spacing: 7) {
                            Circle().fill(fresh == nil ? Color.secondary : Palette.accent).frame(width: 6, height: 6)
                            Text(fresh != nil ? "LIVE HARTSLAG" : model.isRequested ? "WACHTEN OP METING" : "HARTSLAG")
                                .font(.system(size: 11, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(fresh.map { String(Int($0.bpm.rounded())) } ?? "—").font(.system(size: 100, weight: .semibold, design: .rounded)).tracking(-5).monospacedDigit().contentTransition(.numericText())
                            Text("BPM").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                        Text(fresh?.source ?? model.status).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if let latest {
                            Text("Laatste meting \(latest.timestamp.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.tertiary)
                        }
                    }.padding(.vertical, 20).frame(maxWidth: .infinity)

                    Surface {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Text("Tijdlijn").font(.headline); Spacer(); Text(model.isRequested ? "Huidige sessie" : "Laatste sessie").font(.caption).foregroundStyle(.secondary) }
                            Picker("Tijdsvenster", selection: $window) { Text("5 min").tag(5); Text("15 min").tag(15); Text("60 min").tag(60); Text("Alles").tag(0) }.pickerStyle(.segmented)
                            HeartRateChart(samples: visibleSamples(at: timeline.date), threshold: model.settings.threshold.enabled ? model.settings.threshold.bpm : nil)
                            StatisticsRow(samples: model.samples)
                        }
                    }

                    if let notice = model.notice {
                        Label(notice, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack { Label("Meetbron", systemImage: "airpodspro").font(.headline); Spacer(); if model.settings.mode == .daily { Button("Sensor") { showSensors = true }.font(.subheadline) } }
                            Picker("Meetmodus", selection: $model.settings.mode) { ForEach(MonitoringMode.allCases) { Text($0.title).tag($0) } }.disabled(model.isRequested || model.isStopping)
                            if model.settings.mode == .workout {
                                Picker("Activiteit", selection: $model.settings.workout) { ForEach(WorkoutChoice.allCases) { Text($0.title).tag($0) } }.disabled(model.isRequested || model.isStopping)
                                Text("Start alleen voor een echte work-out. Apple Gezondheid kan de sensor automatisch kiezen.").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(model.isManuallySuppressed && !model.isRequested ? "Autostart is onderbroken na Stop. Tik op Start om te hervatten." : "Automatische start is beperkt tot de verbindingen en app-toestanden die iOS toestaat. Geen verse data? Dan toont Heartbeat geen live BPM.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if model.settings.threshold.enabled {
                        Label("Grens \(Int(model.settings.threshold.bpm)) BPM · \(Int(model.settings.threshold.duration)) seconden", systemImage: "bell").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }.background(Palette.background)
        }
        .navigationTitle("Heartbeat").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { if model.isRequested { await model.stop() } else { await model.start() } } } label: {
                    Label(model.isStopping ? "Afronden…" : model.isRequested ? "Stop" : "Start", systemImage: model.isRequested ? "stop.fill" : "play.fill")
                }.buttonStyle(.borderedProminent).disabled(!model.ready || model.isStopping)
                    .accessibilityLabel(model.isRequested ? "Meting stoppen" : "Meting starten")
                    .accessibilityIdentifier("monitor.toggle")
            }
        }
        .sheet(isPresented: $showSensors) { SensorPickerView().environmentObject(model) }
    }
    private func visibleSamples(at now: Date) -> [HeartbeatCore.HeartRateSample] {
        guard window > 0 else { return model.samples }
        let end = model.isRequested ? now : model.samples.last?.timestamp ?? now
        return model.samples.filter { $0.timestamp >= end.addingTimeInterval(-Double(window) * 60) }
    }
}

struct SensorPickerView: View {
    @EnvironmentObject private var model: MonitorModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Draag je AirPods en verbind ze met deze iPhone. Alleen sensoren die een hartslagservice beschikbaar maken verschijnen hier.").font(.subheadline)
                    Button("Opnieuw zoeken") { Task { await model.rescanSensors() } }.disabled(!model.ready || model.isStopping)
                    Button("Sensorvoorkeur wissen") { Task { await model.forgetSensor() } }.disabled(!model.ready || model.isStopping)
                }
                Section("Beschikbare sensoren") {
                    if model.devices.isEmpty { Label("Nog geen hartslagsensor gevonden", systemImage: "antenna.radiowaves.left.and.right").foregroundStyle(.secondary) }
                    ForEach(model.devices) { device in
                        Button { Task { await model.selectSensor(device); dismiss() } } label: { Label(device.name, systemImage: "wave.3.right") }
                    }
                }
                Section { Text("Als AirPods geen openbare hartslagdata leveren, blijft dagelijks meten experimenteel. Probeer dan de work-outmodus voor een echte activiteit.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Hartslagsensor").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gereed") { dismiss() } } }
        }
    }
}
