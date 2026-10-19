import HealthKit
import HeartbeatCore

@MainActor
final class HealthMonitor: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    let healthStore = HKHealthStore()
    var onSample: ((HeartRateSample) -> Void)?
    var onStatus: ((String) -> Void)?
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var lastSampleDate: Date?
    private var generation = UUID()
    private var stopContinuation: CheckedContinuation<Date, Error>?
    private var stopToken: UUID?
    private let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)!

    func start(_ activity: HKWorkoutActivityType) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        let token = UUID(); generation = token
        try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRate, HKObjectType.workoutType()])
        guard generation == token else { return }
        let configuration = HKWorkoutConfiguration(); configuration.activityType = activity; configuration.locationType = .unknown
        let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let newBuilder = newSession.associatedWorkoutBuilder()
        newSession.delegate = self; newBuilder.delegate = self
        newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        session = newSession; builder = newBuilder; lastSampleDate = nil
        let now = Date(); newSession.prepare(); newSession.startActivity(with: now)
        do { try await newBuilder.beginCollection(at: now) }
        catch { newSession.end(); session = nil; builder = nil; throw error }
        guard generation == token else { return }
        onStatus?("Work-out actief. Wachten op hartslag…")
    }
    func stop() async throws {
        generation = UUID()
        guard let session, let builder else { return }
        defer { stopToken = nil; session.end(); session.delegate = nil; builder.delegate = nil; self.session = nil; self.builder = nil }
        let stoppedAt: Date
        if session.state == .stopped || session.state == .ended { stoppedAt = Date() }
        else {
            stoppedAt = try await withCheckedThrowingContinuation { continuation in
                let token = UUID(); stopToken = token
                stopContinuation = continuation
                session.stopActivity(with: Date())
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(15))
                    guard let self, self.stopToken == token, let pending = self.stopContinuation else { return }
                    self.stopContinuation = nil; pending.resume(throwing: HealthError.collection)
                }
            }
        }
        try await builder.endCollection(at: stoppedAt)
        guard try await builder.finishWorkout() != nil else { throw HealthError.collection }
    }
    func history() async throws -> [HeartRateSample] {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        try await healthStore.requestAuthorization(toShare: [], read: [heartRate])
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: Date())
            let query = HKSampleQuery(sampleType: heartRate, predicate: predicate, limit: 10000, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, values, error in
                if let error { continuation.resume(throwing: error); return }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let samples = (values as? [HKQuantitySample] ?? []).map {
                    HeartRateSample(id: $0.uuid, bpm: $0.quantity.doubleValue(for: unit), timestamp: $0.endDate, receivedAt: Date(), source: $0.sourceRevision.source.name, externalID: $0.uuid.uuidString)
                }
                continuation.resume(returning: samples)
            }
            healthStore.execute(query)
        }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor [weak self] in
            guard let self, self.builder === workoutBuilder, collectedTypes.contains(self.heartRate),
                  let statistics = workoutBuilder.statistics(for: self.heartRate), let quantity = statistics.mostRecentQuantity() else { return }
            let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let date = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
            guard self.lastSampleDate != date else { return }
            self.lastSampleDate = date
            self.onSample?(.init(bpm: bpm, timestamp: date, receivedAt: Date(), source: "HealthKit · geselecteerde sensor"))
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            if toState == .stopped, let pending = self.stopContinuation {
                self.stopContinuation = nil; pending.resume(returning: date)
            }
            if toState == .ended {
                self.onStatus?("Work-out beëindigd. Stop de meting om je sessie af te sluiten.")
            }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            if let pending = self.stopContinuation { self.stopContinuation = nil; pending.resume(throwing: error) }
            self.onStatus?("Work-out onderbroken: \(error.localizedDescription)")
        }
    }
    enum HealthError: LocalizedError {
        case unavailable, collection
        var errorDescription: String? { self == .unavailable ? "Apple Gezondheid is niet beschikbaar op dit toestel." : "De work-out kon niet correct worden opgeslagen." }
    }
}
