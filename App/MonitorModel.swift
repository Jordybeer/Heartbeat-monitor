import SwiftUI
import HeartbeatCore
import UserNotifications

@MainActor
final class MonitorModel: ObservableObject {
    static let shared = MonitorModel()
    @Published var settings = MonitorSettings.load() {
        didSet {
            settings.save()
            if oldValue.threshold != settings.threshold { engine = .init(rule: settings.threshold) }
            if oldValue.hideBPM != settings.hideBPM { live.update(freshSample, message: status, hideBPM: settings.hideBPM, force: true) }
            if ready && !oldValue.autoStart && settings.autoStart && !isRequested && hasOnboarded && settings.mode == .daily {
                Task { await start(automatic: true) }
            }
            if oldValue.retentionDays != settings.retentionDays, ready {
                Task { do { try await store?.prune(days: settings.retentionDays); await refreshHistory() } catch { lastError = error.localizedDescription } }
            }
        }
    }
    @Published var hasOnboarded = UserDefaults.standard.bool(forKey: "onboarded")
    @Published private(set) var samples: [HeartRateSample] = []
    @Published private(set) var sessions: [SessionSummary] = []
    @Published private(set) var devices: [SensorDevice] = []
    @Published private(set) var isRequested = false
    @Published private(set) var isStopping = false
    @Published private(set) var ready = false
    @Published var status = "Klaar om te beginnen"
    @Published var lastError: String?
    @Published var notice: String?
    @Published private(set) var sessionStartedAt: Date?
    private(set) var store: SessionStore?
    private var sessionID: UUID?
    private var generation = UUID()
    private var processing: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var engine = ThresholdEngine(rule: MonitorSettings.load().threshold)
    private var bluetooth: BluetoothMonitor?
    let health = HealthMonitor()
    private let live = LiveActivityService()
    private var startReason = "Handmatig gestart"
    var freshSample: HeartRateSample? { samples.last.flatMap { $0.isFresh(at: Date()) ? $0 : nil } }
    var isManuallySuppressed: Bool { UserDefaults.standard.bool(forKey: "manualStop") }

    private init() {
        preparation = Task {
            do {
                let storage = try SessionStore(); store = storage
                try await storage.recoverInterrupted(); try await storage.prune(days: settings.retentionDays)
                await live.end(); await refreshHistory()
                if health.needsRecovery { await attachRecoveredWorkout() }
                ready = true
                if hasOnboarded && settings.autoStart && settings.mode == .daily && !isManuallySuppressed && !isRequested && !isStopping { await start(automatic: true) }
            } catch { lastError = "Meetlog kan niet worden geopend: \(error.localizedDescription)" }
        }
    }
    private func wireHealth(_ token: UUID) {
        health.onSample = { [weak self] sample in Task { @MainActor in self?.enqueue(sample, token: token) } }
        health.onStatus = { [weak self] message in Task { @MainActor in
            guard let self, self.generation == token, self.isRequested else { return }; self.status = message
        } }
    }
    private func attachRecoveredWorkout() async {
        do {
            guard try await health.recover() else { return }
            if isManuallySuppressed || isStopping { try await health.stop(); return }
            settings.mode = .workout
            let token = UUID(); generation = token
            samples = []; sessionID = nil; sessionStartedAt = nil; engine = .init(rule: settings.threshold)
            startReason = "Work-out hersteld na onderbreking"; status = "Work-out hersteld. Wachten op verse hartslag…"
            isRequested = true; wireHealth(token); createLiveActivity()
        } catch { lastError = "Herstellen van de actieve work-out mislukt: \(error.localizedDescription)" }
    }
    func recoverSystemWorkout() async {
        await preparation?.value
        guard !isRequested else { return }
        await attachRecoveredWorkout()
    }
    func completeOnboarding() {
        hasOnboarded = true; UserDefaults.standard.set(true, forKey: "onboarded")
        if ready && settings.autoStart && settings.mode == .daily { Task { await start(automatic: true) } }
    }
    func start(automatic: Bool = false) async {
        guard ready, !isRequested, !isStopping, store != nil else { return }
        UserDefaults.standard.set(false, forKey: "manualStop")
        let token = UUID(); generation = token
        samples = []; sessionID = nil; sessionStartedAt = nil; engine = .init(rule: settings.threshold)
        lastError = nil; notice = nil; isRequested = true
        startReason = automatic ? "Automatisch gestart" : "Handmatig gestart"
        status = "Wachten op een echte meting…"
        createLiveActivity()
        if settings.mode == .daily {
            let sensor = bluetooth ?? BluetoothMonitor(); bluetooth = sensor
            sensor.onSample = { [weak self] sample in Task { @MainActor in self?.enqueue(sample, token: token) } }
            sensor.onDevices = { [weak self] items in Task { @MainActor in self?.devices = items } }
            sensor.onStatus = { [weak self] message in Task { @MainActor in
                guard let self, self.generation == token, self.isRequested else { return }; self.status = message
                if self.freshSample == nil { self.live.update(nil, message: message, hideBPM: self.settings.hideBPM, force: true) }
            } }
            sensor.start()
        } else {
            wireHealth(token)
            do { try await health.start(settings.workout.activity) }
            catch { guard generation == token else { return }; lastError = error.localizedDescription; await stop() }
        }
    }
    private func enqueue(_ sample: HeartRateSample, token: UUID) {
        let previous = processing
        processing = Task { [weak self] in
            await previous?.value
            guard let self, self.isRequested, self.generation == token else { return }
            await self.consume(sample, token: token)
        }
    }
    private func consume(_ sample: HeartRateSample, token: UUID) async {
        guard let store, sample.isFresh(at: Date()), samples.last.map({ sample.timestamp > $0.timestamp }) ?? true else { return }
        do {
            if let last = samples.last, sample.timestamp.timeIntervalSince(last.timestamp) > 120, let oldID = sessionID {
                try await store.end(oldID, at: last.timestamp, reason: "Onderbroken: langer dan twee minuten geen data")
                guard generation == token, isRequested else { return }
                sessionID = nil; samples = []; engine.reset()
            }
            if sessionID == nil {
                let id = try await store.begin(at: sample.timestamp, mode: settings.mode.rawValue, reason: startReason)
                guard generation == token, isRequested else { try await store.end(id, at: sample.timestamp, reason: "Gestopt tijdens verbinden"); return }
                sessionID = id; sessionStartedAt = sample.timestamp
            }
            guard let id = sessionID else { return }
            if let previous = samples.last {
                if sample.timestamp.timeIntervalSince(previous.timestamp) > 15 { try await store.event("Meetgat; geen waarden ingevuld", at: sample.timestamp, sessionID: id) }
                if previous.source != sample.source { try await store.event("Meetbron gewijzigd", at: sample.timestamp, sessionID: id); engine.reset() }
            }
            try await store.append(sample, sessionID: id)
            guard generation == token, isRequested else { return }
            samples.append(sample); status = "Meten"
            live.update(sample, message: "Meten", hideBPM: settings.hideBPM)
            let appliedRule = settings.threshold
            if let trigger = engine.consume(sample, now: Date()) {
                try await store.event("Grens overschreden: \(Int(trigger.bpm)) BPM boven \(Int(trigger.threshold)) BPM", at: trigger.triggeredAt, sessionID: id)
                guard generation == token, isRequested, settings.threshold == appliedRule else { return }
                do {
                    try await NotificationService.send(trigger, hideBPM: settings.hideBPM)
                    try await store.event("Notificatie bij iOS aangevraagd", sessionID: id)
                } catch {
                    notice = "Melding kon niet worden aangevraagd. Controleer notificatietoegang."
                    try await store.event("Notificatieverzoek mislukt", sessionID: id)
                }
            }
        } catch {
            lastError = "Opslaan mislukt; meting wordt gestopt: \(error.localizedDescription)"
            Task { await stop() }
        }
    }
    func stop() async {
        guard !isStopping else { return }
        isStopping = true; isRequested = false; generation = UUID()
        UserDefaults.standard.set(true, forKey: "manualStop")
        await preparation?.value
        bluetooth?.stop(); status = "Afronden…"
        await processing?.value; processing = nil
        do { try await health.stop() } catch { lastError = "Work-out kon niet volledig worden afgerond: \(error.localizedDescription)" }
        if let sessionID {
            do { try await store?.end(sessionID, at: samples.last?.timestamp ?? Date(), reason: "Gestopt") }
            catch { lastError = "Sessie-einde kon niet worden opgeslagen: \(error.localizedDescription)" }
        }
        sessionID = nil; engine.reset(); await live.end(); await refreshHistory()
        status = "Gestopt"; isStopping = false
    }
    func createLiveActivity() {
        guard isRequested, UIApplication.shared.applicationState == .active else { return }
        do { try live.begin(mode: settings.mode == .daily ? "Dagelijkse meting" : settings.workout.title, hideBPM: settings.hideBPM) }
        catch { notice = "Live Activity niet beschikbaar: \(error.localizedDescription)" }
        live.update(freshSample, message: freshSample == nil ? "Wachten op meting" : "Meten", hideBPM: settings.hideBPM, force: true)
    }
    func selectSensor(_ device: SensorDevice) async {
        await stop()
        let sensor = bluetooth ?? BluetoothMonitor(); bluetooth = sensor
        sensor.select(device.id); await start()
    }
    func rescanSensors() async {
        if !isRequested { await start() }
        bluetooth?.rescan()
    }
    func forgetSensor() async {
        await stop()
        bluetooth?.forget(); devices = []
        await start()
    }
    func refreshHistory() async {
        do { sessions = try await store?.sessions() ?? [] } catch { lastError = "Geschiedenis niet beschikbaar: \(error.localizedDescription)" }
    }
    func deleteHistory() async {
        guard !isRequested, !isStopping else { return }
        do { try await store?.deleteAll(); samples = []; sessions = [] } catch { lastError = error.localizedDescription }
    }
    func enableNotifications() async {
        do {
            let allowed = try await NotificationService.request()
            settings.threshold.enabled = allowed
            if !allowed { notice = "Meldingen zijn niet toegestaan. Je kunt dit aanpassen in iOS Instellingen." }
        } catch { lastError = error.localizedDescription; settings.threshold.enabled = false }
    }
}
