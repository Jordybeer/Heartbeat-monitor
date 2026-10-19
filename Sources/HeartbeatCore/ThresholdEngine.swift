import Foundation

public struct ThresholdRule: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var bpm: Double
    public var duration: TimeInterval
    public var rearmMargin: Double
    public var maximumGap: TimeInterval
    public init(enabled: Bool = false, bpm: Double = 120, duration: TimeInterval = 30, rearmMargin: Double = 5, maximumGap: TimeInterval = 15) {
        self.enabled = enabled; self.bpm = bpm; self.duration = duration
        self.rearmMargin = rearmMargin; self.maximumGap = maximumGap
    }
}

public struct ThresholdTrigger: Sendable {
    public let beganAt: Date
    public let triggeredAt: Date
    public let bpm: Double
    public let threshold: Double
}

public struct ThresholdEngine: Sendable {
    public var rule: ThresholdRule
    private var beganAt: Date?
    private var lastTimestamp: Date?
    private var lastID: UUID?
    private var latched = false
    public init(rule: ThresholdRule) { self.rule = rule }
    public mutating func reset() { beganAt = nil; lastTimestamp = nil; lastID = nil; latched = false }
    public mutating func consume(_ sample: HeartRateSample, now: Date) -> ThresholdTrigger? {
        guard rule.enabled, rule.bpm.isFinite, rule.bpm > 0, rule.duration >= 0,
              rule.rearmMargin >= 0, rule.maximumGap > 0 else { beganAt = nil; return nil }
        guard sample.isFresh(at: now), sample.id != lastID else { return nil }
        if let previous = lastTimestamp, sample.timestamp <= previous { return nil }
        if let previous = lastTimestamp, sample.timestamp.timeIntervalSince(previous) > rule.maximumGap { beganAt = nil }
        lastTimestamp = sample.timestamp; lastID = sample.id
        if sample.bpm <= rule.bpm - rule.rearmMargin { latched = false }
        guard sample.bpm > rule.bpm else { beganAt = nil; return nil }
        guard !latched else { return nil }
        if beganAt == nil { beganAt = sample.timestamp }
        guard let beganAt, sample.timestamp.timeIntervalSince(beganAt) >= rule.duration else { return nil }
        latched = true
        return .init(beganAt: beganAt, triggeredAt: sample.timestamp, bpm: sample.bpm, threshold: rule.bpm)
    }
}
