import XCTest
@testable import HeartbeatCore

final class HeartbeatCoreTests: XCTestCase {
    let base = Date(timeIntervalSince1970: 1_000_000)
    func sample(_ bpm: Double, _ seconds: Double, id: UUID = UUID()) -> HeartRateSample {
        HeartRateSample(id: id, bpm: bpm, timestamp: base.addingTimeInterval(seconds), source: "Test")
    }
    func testSustainedThresholdNeedsFreshCoverage() {
        var engine = ThresholdEngine(rule: .init(enabled: true, bpm: 120, duration: 30))
        for time in [0.0, 10, 20] { XCTAssertNil(engine.consume(sample(130, time), now: base.addingTimeInterval(time))) }
        XCTAssertNotNil(engine.consume(sample(130, 30), now: base.addingTimeInterval(30)))
        XCTAssertNil(engine.consume(sample(140, 40), now: base.addingTimeInterval(40)))
    }
    func testGapResetsPendingThreshold() {
        var engine = ThresholdEngine(rule: .init(enabled: true, bpm: 120, duration: 30))
        XCTAssertNil(engine.consume(sample(130, 0), now: base))
        XCTAssertNil(engine.consume(sample(130, 31), now: base.addingTimeInterval(31)))
    }
    func testMustRecoverBelowMarginBeforeAnotherAlert() {
        var engine = ThresholdEngine(rule: .init(enabled: true, bpm: 120, duration: 0))
        XCTAssertNotNil(engine.consume(sample(130, 0), now: base))
        XCTAssertNil(engine.consume(sample(119, 1), now: base.addingTimeInterval(1)))
        XCTAssertNil(engine.consume(sample(130, 2), now: base.addingTimeInterval(2)))
        XCTAssertNil(engine.consume(sample(114, 3), now: base.addingTimeInterval(3)))
        XCTAssertNotNil(engine.consume(sample(130, 4), now: base.addingTimeInterval(4)))
    }
    func testStaleFutureAndDuplicateSamplesCannotAlert() {
        var engine = ThresholdEngine(rule: .init(enabled: true, bpm: 120, duration: 0))
        XCTAssertNil(engine.consume(sample(130, 0), now: base.addingTimeInterval(60)))
        XCTAssertNil(engine.consume(sample(130, 10), now: base))
        let item = sample(130, 0)
        XCTAssertNotNil(engine.consume(item, now: base))
        XCTAssertNil(engine.consume(item, now: base))
    }
    func testOutOfOrderAndThresholdEqualityDoNotAlert() {
        var engine = ThresholdEngine(rule: .init(enabled: true, bpm: 120, duration: 0))
        XCTAssertNil(engine.consume(sample(120, 10), now: base.addingTimeInterval(10)))
        XCTAssertNil(engine.consume(sample(130, 9), now: base.addingTimeInterval(10)))
    }
    func testDisabledRuleDoesNotAlert() {
        var engine = ThresholdEngine(rule: .init(enabled: false, bpm: 120, duration: 0))
        XCTAssertNil(engine.consume(sample(160, 0), now: base))
    }
    func testBluetoothEightAndSixteenBitPackets() {
        XCTAssertEqual(HeartRatePacket.decode(Data([0x00, 72]))?.bpm, 72)
        XCTAssertEqual(HeartRatePacket.decode(Data([0x01, 0x2C, 0x01]))?.bpm, 300)
    }
    func testBluetoothRejectsTruncationZeroAndLostContact() {
        let invalid: [[UInt8]] = [[], [1], [1, 44], [0, 0], [0x04, 72], [0x08, 72], [0x10, 72, 1]]
        for bytes in invalid {
            XCTAssertNil(HeartRatePacket.decode(Data(bytes)), "Invalid packet: \(bytes)")
        }
        XCTAssertEqual(HeartRatePacket.decode(Data([0x06, 72]))?.bpm, 72)
    }
    func testChartsNeverBridgeMissingMeasurements() {
        let segments = ChartSegments.split([sample(80, 0), sample(90, 5), sample(100, 30)], maximumGap: 15)
        XCTAssertEqual(segments.map(\.count), [2, 1])
    }
    func testCSVQuotesSourceAndKeepsExactTimestamp() {
        let text = CSVExport.render([HeartRateSample(bpm: 82, timestamp: Date(timeIntervalSince1970: 0), source: "AirPods, \"left\"")])
        XCTAssertTrue(text.contains("1970-01-01T00:00:00.000Z"))
        XCTAssertTrue(text.contains("\"AirPods, \"\"left\"\"\""))
    }
    func testChartSeparatesSensorChangesWithoutAGap() {
        let a = HeartRateSample(bpm: 80, timestamp: base, source: "AirPods")
        let b = HeartRateSample(bpm: 90, timestamp: base.addingTimeInterval(1), source: "Other sensor")
        XCTAssertEqual(ChartSegments.split([a,b]).map(\.count), [1,1])
    }
    func testSensorNamesCannotBecomeSpreadsheetFormulas() {
        let item = HeartRateSample(bpm: 80, timestamp: base, source: "=1+1")
        XCTAssertTrue(CSVExport.render([item]).contains("\"'=1+1\""))
    }
}
