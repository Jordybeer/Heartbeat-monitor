# Autonomous implementation decisions

The user authorized autonomous execution after blueprint 0.5. These defaults are visible and editable, not inferred personal or medical facts.

- Daily mode attempts the public BLE heart-rate service. AirPods exposure outside workouts is experimental, with an explicit waiting state and sensor picker. No private service is used.
- Workout mode is explicitly started by the user for an actual chosen activity. It may use HealthKit's automatically selected sensor and is labeled accordingly.
- Automatic daily connection is preferred after onboarding; manual stop stays suppressed until the user explicitly resumes. No cold launch/in-ear detection guarantee.
- Alerts initially disabled. Editable example limit 120 BPM, duration 30 seconds (including a 0-second option), 5 BPM rearm margin, 15-second maximum gap and sample freshness. These are software defaults, not medical advice or personalized limits.
- Keep local sessions 30 days by default (7/30/90/unlimited available). No account, cloud sync or analytics. CSV sharing is explicit.
- HealthKit history is read-only and presented separately. Direct BLE measurements are not exported into HealthKit until duplicate behavior is validated. Real workouts use Apple's builder.
- Use Core Data with file protection after first unlock, and preserve incomplete sessions as interrupted rather than inventing continuity.
- Build on a GitHub macOS runner with an iOS 26+ SDK. Record the exact selected Xcode/SDK in build metadata. Generate the Xcode project from tracked XcodeGen configuration.
- Develop on codex/oneshot; pull request and Actions artifacts are the concrete review/delivery surfaces.

# Execution ledger

- Repository was empty; initialized README on main and isolated implementation on codex/oneshot.
- Ruling: user autonomous one-shot authorizes implementation, repository commits and CI execution without additional design approvals.
- Pre-flight: app and widget share only ActivityAttributes; domain package has no Apple sensor dependency. CI runs package tests and compiles both targets.
- Domain TDD: run 39238522105 failed on missing types; run 39238780295 passed all 10 initial tests. Run 39240520688 demonstrated two failing regressions for source-change segmentation and spreadsheet-formula escaping before implementing their fixes.
- Independent review found remembered-peripheral discovery blocking replacement sensors and missing active HealthKit workout recovery. Reconnect now keeps discovery available, the picker exposes rescan/forget, and bootstrap restores system workouts before automatic daily start or a cold Stop intent.
- First device compile reached Xcode 26.3 and exposed missing Foundation imports in the notification/live-activity services; imports corrected. A successful device build is still required before delivery.
- Focused re-review identified concurrent Stop/recovery and a notification/logging error boundary. Stop now coalesces callers and recovery is serialized; persistence errors remain storage errors. Reviewer confirmed the fixes by inspection. The workout recovery scene property requires importing HealthKitUI, as in Apple's reference sample.

- Native verification: run 39241307543 passed the iPhone app/widget build, all 12 domain tests and the onboarding/monitor/history/settings UI test.
- Visual QA of the exported iPhone 17 screens found the primary Start action below the fold. Start/Stop moved to the persistent navigation toolbar, the UI test now asserts it is hittable without scrolling, and onboarding explicitly inherits the coral accent.
- Packaging review: the final IPA uses a certificate-free ad hoc metadata signature so a re-signer can discover HealthKit rights. It still requires personal-account device signing. The workflow extracts/asserts the embedded entitlement, verifies app/widget signatures and checks the IPA layout; no signing credentials enter CI. SideStore account-specific provisioning remains a physical-device check.
- CI observability: after run 39242597504 passed compilation/package checks but its screen-test command produced no completion after ten minutes, simulator boot became a separate bounded step. UI tests use one destination with parallel clones disabled and explicit test/step timeouts. This isolates simulator startup from test execution and preserves failure logs.
- Run 39244243741 isolated a five-minute timeout in `simctl boot` before any test launched. Apple's [Xcode 26.4 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_4-release-notes) describe fixed simdiskimaged jetsam loops that manifest as simctl hangs (172343027). This is consistent with the observed failure; it is not an app-test assertion failure. CI now uses the macOS 26 image, requires stable Xcode 26.4+ and selects the newest available iOS 26+ iPhone 17 runtime. See the [runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).
