# Heartbeat verification plan

> **For agentic workers:** Use superpowers:executing-plans for this test-only task.

**Goal:** Re-run the shipped app and add observable checks for session controls, background return and saved settings.

**Architecture:** Exercise the existing app through XCTest UI automation and the existing Swift package. No sensor simulation, launch-time test hooks or production behavior changes.

**Tech Stack:** Swift XCTest, Xcode 26.4+, iPhone 17 simulator, GitHub Actions.

**Spec:** `docs/blueprint.md`, with shipped behavior described in `README.md`.

## Global constraints

- Minimum iOS 26.0; keep the Live Activity extension in the IPA.
- No fabricated heart-rate samples in the app.
- Daily AirPods reception, locked-screen reception, HealthKit signing and long sessions require physical hardware.

## Review focus

- A visible Start/Stop button must actually change session state.
- Returning from the home screen must retain a requested monitoring session.
- Manual Stop must suppress autostart even after a cold launch with autostart enabled.
- The BPM privacy preference must survive a cold launch.
- Freshness limits and an interrupted threshold crossing must not create false alerts.

## Task 1: Observable regression coverage

**Files:** `UITests/HeartbeatUITests.swift`, `Tests/HeartbeatCoreTests/HeartbeatCoreTests.swift`.

**Interfaces:** Existing accessibility identifier `monitor.toggle`; existing settings switches and public `HeartRateSample.isFresh` / `ThresholdEngine.consume` APIs.

- [ ] Add a session test that enables autostart, stops, cold-launches, explicitly starts, backgrounds, returns and stops again. Assert button labels after every transition.
- [ ] Add a privacy test that changes the switch and asserts its saved value after a cold launch.
- [ ] Add freshness boundary assertions at -2 and 15 seconds, rejecting values just outside the window and non-positive/non-finite BPM.
- [ ] Add a threshold test where a return to the threshold resets the pending duration.
- [ ] Run `swift test` and the workflow's full `xcodebuild test` on macOS. Expected: all package and UI tests pass.
- [ ] Review the new background screenshot without claiming that a screenshot proves sensor delivery.
- [ ] Open a reviewable test-only PR; report the exact CI result and remaining hardware checks.

These tests cover existing behavior. A failing assertion will be investigated before any production fix; passing tests alone do not establish a RED-to-GREEN bug fix.

## CI finding

Both the unchanged main re-run and the test-only run timed out during the simulator's initial data migration, before launching Heartbeat. The previous successful run used the same Xcode 26.6 / iOS 26.5 image and completed its cold boot in about three minutes. Increase only the boot-step budget from five to ten minutes; retain the overall thirty-minute job bound and all test assertions. A successful boot and executed UI tests are required before calling verification complete.

Run 15 completed simulator boot and executed all three UI tests. The two new tests failed before their lifecycle/persistence checks because XCTest tapped the center of a SwiftUI switch's labeled row. Exported event records show x=201 while the actual switch is on the right. Target the trailing control within the element's frame and wait for its expected accessibility value. Keep all lifecycle and persistence assertions; production code remains unchanged.

Run 18 built and packaged successfully, but the autostart switch stayed off after the synthetic row-coordinate tap. The exported accessibility query identifies a 370×52 labeled row and a separate 63×28 native switch. Resolve the unlabeled native switch contained in that row and press the control itself. Preserve the expected-value assertion and every lifecycle check. Run all UI tests three times without retry-on-failure so an intermittent failure still fails CI. Validate on the PR and again on main before reporting the fix complete.

Run 16 passed all fourteen package and three UI tests. Its background capture caught the home-transition animation, so it cannot confirm a settled background interval or the Live Activity's appearance. Strengthen the same lifecycle test to await the actual background/suspended state, remain there for ten seconds, assert the process is still in the background and then return. This is a short lifecycle check, not proof of sensor reception or long-session stability.
