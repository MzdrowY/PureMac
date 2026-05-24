<!-- Last session: 2026-05-24 08:38 -->
<!-- Last session: 2026-05-24 08:38 -->
# PureMac - Maintenance Handoff

## Current Objective
v2.5.0 shipped (signed/notarized/Homebrew bumped via release run 26353043465). Adds Arc-style onboarding with live SwiftUI FDA demo, restraint pass on chrome, mission-driven README. v2.4.0 (shipped same session) added the PermissionCoordinator-driven FDA flow.

## Recently Modified (this session)

### v2.4.0 (commits 42d9a94, f6f46c2)
- `PureMac/Services/PermissionCoordinator.swift` (new) - polled FDA coordinator with retry callback. Single source of truth for permission prompts across cleanup + uninstall flows.
- `PureMac/Views/Components/PermissionSheet.swift` (new) - sheet UI with "Open Settings & reveal PureMac", listening indicator, advanced help disclosure, blocked-paths list.
- `PureMac/Services/FullDiskAccessManager.swift` - `triggerRegistration()` widened from 3 to 10 probe paths so macOS catalogs more TCC services.
- `PureMac/ViewModels/AppState.swift` - `cleanErrorIsFDAFixable`, `pendingPermissionRetryItems`, `requestFullDiskAccessAndRetry(items:context:)`, `retryCleanItems(_:)`, `handleCleanOutcome(errors:survivors:)`. Cleanup paths stash survivors + distinguish FDA-fixable vs other failures.
- `PureMac/Views/MainWindow.swift` - alert replaced by PermissionSheet; sidebar selection styling; FDA toast becomes quiet tinted bar.
- `PureMac/Views/Apps/AppFilesView.swift` - removalNeedsFullDiskAccess routes into the coordinator.
- `PureMac/Views/Components/AppTheme.swift` - CardSurface elevation tiers, IconTile depth, StatusChip + PressableScale modifier.
- `PureMac/Views/DashboardView.swift` - hero/stats/suggestion polish + macOS 14 symbolEffect gating.

### v2.5.0 (commit 5c728b7, 07fe27a)
- `PureMac/Views/Components/FDADemoView.swift` (new) - looping SwiftUI illustration of the System Settings Full Disk Access pane. Row pulse → toggle slides on → green check → hold → reset (~4.3s cycle). isActive-guarded cycle() so it stops on disappear.
- `PureMac/Views/OnboardingView.swift` - Arc-style 4-page rewrite (welcome → mission → permission with embedded FDADemoView → ready). 680x560 window. Auto-advances on FDA grant via 1s poll while on permission page.
- `PureMac/Views/Components/AppTheme.swift` - restraint pass. CardSurface drops accent stripe, IconTile drops glow, gauges lose gradient FG + halo blur + tip dot. StatusChip flattens to single tint.
- `PureMac/Views/Components/PermissionSheet.swift` - header circle flattens, primary CTA uses native borderedProminent.
- `PureMac/Views/DashboardView.swift` - numeric counters lose gradient FG, cleanedHero simplified.
- `PureMac/Views/MainWindow.swift` - FDA toast becomes single tinted bar (no gradient/glow). Footer fix button uses .bordered instead of gradient pill.
- `PureMac/Views/CategoryDetailView.swift` - hero font .bold -> .semibold.
- `README.md` - mission-driven rewrite. Anti-competitive Apple storage framing, no-telemetry/no-network promise, per-scanner explainer, security section.
- `project.yml` + `PureMac.xcodeproj/project.pbxproj` - MARKETING_VERSION 2.5.0, CURRENT_PROJECT_VERSION 9.
- All 7 locales at 285 keys parity (en/ar/es/ja/pt-BR/zh-Hans/zh-Hant).

## Outcomes

| PR | Action | Notes |
| --- | --- | --- |
| _none_ | - | No PRs open. |

| Issue | Action | Notes |
| --- | --- | --- |
| #94 | Commented, open | v2.4.0+ permission UX progress note. Stays open until Sparkle Stage 2 ships (per #104). |
| #104 | Commented, open | v2.5.0 prep note. Appcast/EdDSA/release-workflow work still pending. |

## Next Steps / Blockers

1. Codex review (background agent aca864e6aa1ff9fe4) was queued at end of session. If it returns actionable Critical/High findings, address them in v2.5.1 hotfix. Findings file: `/private/tmp/claude-501/-Users-moamenbasel-Desktop-Projects-PureMac/ed4ffb70-1181-4348-87c5-a90e47f15be5/tasks/aca864e6aa1ff9fe4.output`.
2. Sparkle Stage 2 (issue #104) - EdDSA key generation, SUFeedURL + SUPublicEDKey, appcast generation in release.yml, Sparkle nested-bundle re-sign verification. Out of scope for v2.5.0.
3. Stale localization keys from the old onboarding (`In System Settings, do this:`, `Find **PureMac** and turn the toggle on`, `Authenticate with Touch ID or your password`, `Trouble?`, diagnostics labels, `%lld/%lld protected locations accessible`, `Hide/Show diagnostics`) are dead but harmless - parity test only enforces matching key sets, not unused-key removal. Clean up next session if doing locale work.

## Open Surface
- Open PRs: none.
- Open issues: #94 (Auto Updates tracking), #104 (Sparkle Stage 2).
- Release artifacts: https://github.com/momenbasel/PureMac/releases/tag/v2.5.0 (dmg + zip, both notarized + stapled).
- Homebrew cask: `homebrew/puremac.rb` at sha256 7ceb934ce8d2... (auto-bumped by release.yml).
- Homebrew tap: `momenbasel/homebrew-tap` auto-pushed by release.yml.
