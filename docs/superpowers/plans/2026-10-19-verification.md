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
