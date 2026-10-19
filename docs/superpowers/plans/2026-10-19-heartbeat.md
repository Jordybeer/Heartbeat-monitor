# Heartbeat implementation plan

> For agentic workers: use superpowers:executing-plans inline. User explicitly authorized an autonomous one-shot on 2026-10-19; continue without intermediate approval prompts.

**Goal:** Build a native iOS 26+ heart-rate monitor and produce an unsigned IPA through GitHub Actions for SideStore.
**Architecture:** A Foundation-only Swift package owns sample parsing, threshold evaluation and graph segmentation. The SwiftUI app owns Core Bluetooth, explicit HealthKit workouts, Core Data storage, notifications and ActivityKit. The widget consumes a small shared ActivityAttributes type.
**Tech stack:** Swift 5 language mode, SwiftUI, Swift Charts, HealthKit, Core Bluetooth, Core Data, ActivityKit, WidgetKit, XcodeGen, GitHub Actions.
**Spec:** `docs/blueprint.md` plus `docs/decisions.md` for autonomous rulings.

## Global constraints
- iPhone 17 / AirPods Pro 3; iOS 26 minimum; no private APIs, background audio tricks or fake workouts.
- Actual measurements only; visible timestamps and gaps; data availability is not sensor accuracy.
- GitHub repository Jordybeer/Heartbeat-monitor; unsigned IPA for free-account SideStore signing.
- Autostart preference is configurable and best effort; manual stop must suppress immediate restart.
- No signing credentials or health data in source control or CI.

## Review focus
- Duplicate, stale or out-of-order samples must not cause alerts.
- Missing Bluetooth service, denied HealthKit reads and lost contact must show unavailable data.
- Manual stop, source changes and late delegate callbacks must not recreate sessions.
- Archive must contain both app and widget; unsigned output must not be labeled install-ready.
- Database failures must be visible and must not erase existing logs.

## Task 1: Measurement domain
Files: `Package.swift`, `Sources/HeartbeatCore/*`, `Tests/HeartbeatCoreTests/*`.
Produces: `HeartRateSample`, `ThresholdRule`, `ThresholdEngine.consume(_:now:)`, `HeartRatePacket.decode(_:)`, `ChartSegments.split(_:maximumGap:)`.
- [ ] Write tests for sustained thresholds, reset on gaps, rearming, stale/duplicate/order rejection, both BLE formats and graph gaps.
- [ ] Run `swift test` in GitHub Actions and observe missing-feature failure.
- [ ] Implement domain; run `swift test` and confirm green.

## Task 2: Device app and persistence
Files: `App/Services/*`, `App/Models/*`, `App/HeartbeatApp.swift`, `App/Views/*`, `Shared/*`.
Consumes: the domain types above. Produces: native screens and `MonitorModel` as the single session authority.
- [ ] Implement public BLE heart-rate service discovery with explicit sensor selection and restoration.
- [ ] Implement explicit walking/running/cycling HealthKit workouts and separate read-only HealthKit history.
- [ ] Implement Core Data measurements/sessions/events and timestamped CSV export.
- [ ] Implement editable alert rules, privacy, autostart and retention; defaults recorded in decisions.
- [ ] Implement native charts and all empty/error/stale states.

## Task 3: System surfaces and IPA
Files: `Widget/*`, `.github/workflows/ios.yml`, `project.yml`, `scripts/*`.
- [ ] Implement Live Activity layouts and stop intent, local notifications and freshness.
- [ ] Build generic iOS app and widget using `xcodebuild CODE_SIGNING_ALLOWED=NO`.
- [ ] Package `Payload/Heartbeat.app` with widget into IPA; verify bundle layout and entitlements template.
- [ ] Run the complete workflow; inspect compile errors, fix causes and rerun until green.

## Task 4: Review and delivery
- [ ] Obtain one independent whole-change review and fix material issues.
- [ ] Confirm tests, device build and downloadable IPA artifact from the same commit.
- [ ] Document SideStore installation, limits, unverified hardware behavior and release checklist.
