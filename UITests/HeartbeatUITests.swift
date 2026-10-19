import XCTest

final class HeartbeatUITests: XCTestCase {
    func testOnboardingMonitorHistoryAndSettings() {
        let app = XCUIApplication()
        app.launch()
        let begin = app.buttons["Beginnen"]
        if begin.waitForExistence(timeout: 10) {
            screenshot("Onboarding")
            for _ in 0..<5 where !begin.isHittable { app.swipeUp() }
            let automatic = app.switches["Automatisch starten bij AirPods-gebruik"]
            if automatic.value as? String == "1" { automatic.tap() }
            begin.tap()
        }
        XCTAssertTrue(app.staticTexts["Tijdlijn"].waitForExistence(timeout: 10))
        screenshot("Monitor")
        app.tabBars.buttons["Geschiedenis"].tap()
        XCTAssertTrue(app.staticTexts["Nog geen meetlog"].waitForExistence(timeout: 5))
        screenshot("History")
        app.tabBars.buttons["Instellingen"].tap()
        XCTAssertTrue(app.switches["Automatisch starten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Melding bij overschrijding"].exists)
        screenshot("Settings")
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
