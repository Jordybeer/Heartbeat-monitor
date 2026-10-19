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
