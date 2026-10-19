import XCTest

final class HeartbeatUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingMonitorHistoryAndSettings() {
        let app = XCUIApplication()
        app.launch()
        let begin = app.buttons["Beginnen"]
        if begin.waitForExistence(timeout: 10) {
            screenshot("Onboarding")
            for _ in 0..<5 where !begin.isHittable { app.swipeUp() }
            let automatic = app.switches["Automatisch starten bij AirPods-gebruik"]
            setSwitch(automatic, enabled: false)
            begin.tap()
        }
        XCTAssertTrue(app.staticTexts["Tijdlijn"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["monitor.toggle"].isHittable, "Start/Stop must be reachable without scrolling")
        screenshot("Monitor")
        app.tabBars.buttons["Geschiedenis"].tap()
        XCTAssertTrue(app.staticTexts["Nog geen meetlog"].waitForExistence(timeout: 5))
        screenshot("History")
        app.tabBars.buttons["Instellingen"].tap()
        XCTAssertTrue(app.switches["Automatisch starten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Melding bij overschrijding"].exists)
        screenshot("Settings")
    }

    func testSessionControlsBackgroundReturnAndManualStopPersistence() {
        let app = XCUIApplication()
        app.launch()
        finishOnboardingIfNeeded(app)

        app.tabBars.buttons["Instellingen"].tap()
        let automatic = app.switches["Automatisch starten"]
        XCTAssertTrue(automatic.waitForExistence(timeout: 10))
        setSwitch(automatic, enabled: false)
        setSwitch(automatic, enabled: true)
        app.tabBars.buttons["Nu"].tap()

        let toggle = app.buttons["monitor.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        assertLabel("Meting stoppen", on: toggle)
        toggle.tap()
        assertLabel("Meting starten", on: toggle)

        app.terminate()
        app.launch()
        assertLabel("Meting starten", on: app.buttons["monitor.toggle"])
        app.tabBars.buttons["Instellingen"].tap()
        XCTAssertEqual(app.switches["Automatisch starten"].value as? String, "1", "Stop must suppress autostart without changing the user's preference")
        app.tabBars.buttons["Nu"].tap()

        app.buttons["monitor.toggle"].tap()
        assertLabel("Meting stoppen", on: app.buttons["monitor.toggle"])
        XCTAssertTrue(app.staticTexts["WACHTEN OP METING"].exists)
        screenshot("MonitoringWithoutSensor")

        XCUIDevice.shared.press(.home)
        screenshot("BackgroundLiveActivity")
        app.activate()
        assertLabel("Meting stoppen", on: app.buttons["monitor.toggle"])

        app.buttons["monitor.toggle"].tap()
        assertLabel("Meting starten", on: app.buttons["monitor.toggle"])
        app.terminate()
        app.launch()
        assertLabel("Meting starten", on: app.buttons["monitor.toggle"])
    }

    func testSettingsPrivacyPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launch()
        finishOnboardingIfNeeded(app)
        app.tabBars.buttons["Instellingen"].tap()
        let privacy = app.switches["Verberg BPM op toegangsscherm"]
        for _ in 0..<5 where !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        let previous = privacy.value as? String
        XCTAssertTrue(previous == "0" || previous == "1")
        let expected = previous == "1" ? "0" : "1"
        setSwitch(privacy, enabled: expected == "1")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Instellingen"].tap()
        let restored = app.switches["Verberg BPM op toegangsscherm"]
        for _ in 0..<5 where !restored.isHittable { app.swipeUp() }
        XCTAssertEqual(restored.value as? String, expected)
    }

    private func finishOnboardingIfNeeded(_ app: XCUIApplication) {
        let begin = app.buttons["Beginnen"]
        if begin.waitForExistence(timeout: 2) {
            for _ in 0..<5 where !begin.isHittable { app.swipeUp() }
            begin.tap()
        }
        XCTAssertTrue(app.staticTexts["Tijdlijn"].waitForExistence(timeout: 10))
    }

    private func assertLabel(_ label: String, on element: XCUIElement) {
        let ready = NSPredicate(format: "exists == true AND enabled == true AND label == %@", label)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: element)], timeout: 10)
        XCTAssertEqual(result, .completed, "Expected enabled session control: \(label); got \(element.label)")
    }

    private func setSwitch(_ element: XCUIElement, enabled: Bool) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        let expected = enabled ? "1" : "0"
        if element.value as? String != expected {
            XCTAssertTrue(element.isHittable)
            // SwiftUI exposes the whole labeled row as a switch. Hit the trailing control.
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let changed = NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: element)], timeout: 10)
        XCTAssertEqual(result, .completed, "Expected switch value \(expected); got \(String(describing: element.value))")
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
