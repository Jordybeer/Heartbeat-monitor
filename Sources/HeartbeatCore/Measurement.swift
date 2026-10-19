import Foundation

public struct HeartRateSample: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var bpm: Double
    public var timestamp: Date
    public var receivedAt: Date
    public var source: String
    public var externalID: String?
    public init(id: UUID = UUID(), bpm: Double, timestamp: Date, receivedAt: Date? = nil, source: String, externalID: String? = nil) {
        self.id = id; self.bpm = bpm; self.timestamp = timestamp
        self.receivedAt = receivedAt ?? timestamp; self.source = source; self.externalID = externalID
    }
    public func isFresh(at now: Date, maximumAge: TimeInterval = 15) -> Bool {
        bpm.isFinite && bpm > 0 && now.timeIntervalSince(timestamp) >= -2 && now.timeIntervalSince(timestamp) <= maximumAge
    }
}

public struct HeartRatePacket: Sendable {
    public let bpm: Double
    public let contactDetected: Bool?
    public static func decode(_ data: Data) -> HeartRatePacket? {
        let bytes = Array(data)
        guard let flags = bytes.first else { return nil }
        let wide = flags & 1 != 0
        var cursor = wide ? 3 : 2
        guard bytes.count >= cursor else { return nil }
        let value = wide ? Int(bytes[1]) | (Int(bytes[2]) << 8) : Int(bytes[1])
        guard value > 0 else { return nil }
        let supportsContact = flags & 4 != 0
        let detected = flags & 2 != 0
        guard !supportsContact || detected else { return nil }
        if flags & 8 != 0 { cursor += 2; guard bytes.count >= cursor else { return nil } }
        if flags & 16 != 0 {
            guard bytes.count > cursor, (bytes.count - cursor) % 2 == 0 else { return nil }
        } else if bytes.count != cursor { return nil }
        return .init(bpm: Double(value), contactDetected: supportsContact ? detected : nil)
    }
}

public enum ChartSegments {
    public static func split(_ samples: [HeartRateSample], maximumGap: TimeInterval = 15) -> [[HeartRateSample]] {
        var result: [[HeartRateSample]] = []
        for sample in samples.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let last = result.last?.last, sample.timestamp.timeIntervalSince(last.timestamp) <= maximumGap {
                result[result.count - 1].append(sample)
            } else { result.append([sample]) }
        }
        return result
    }
}

public enum CSVExport {
    public static func render(_ samples: [HeartRateSample]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func quoted(_ string: String) -> String { "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let rows = samples.sorted { $0.timestamp < $1.timestamp }.map {
            [formatter.string(from: $0.timestamp), formatter.string(from: $0.receivedAt), String($0.bpm), quoted($0.source), $0.id.uuidString].joined(separator: ",")
        }
        return (["timestamp_utc,received_at_utc,bpm,source,id"] + rows).joined(separator: "\r\n") + "\r\n"
    }
}
