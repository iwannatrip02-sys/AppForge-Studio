# AppForge Studio — Build Guide
> Updated: 2026-05-26

## Quick Start (No Mac Required)

### 1. Build on GitHub Actions (Free)
```
git push origin main
→ GitHub Actions triggers automatically
→ macOS runner builds unsigned .ipa
→ Download artifact from Actions tab
→ Sideloadly on Windows signs with free Apple ID
→ Install to iPad via USB
```

### 2. Sideload to iPad
```
1. Install Sideloadly on Windows (sideloadly.io)
2. Install iTunes + iCloud from apple.com (NOT Microsoft Store)
3. Connect iPad via USB
4. Drag .ipa into Sideloadly
5. Enter your free Apple ID
6. App installs to iPad (valid 7 days, auto-refresh)
```

### 3. CI Pipeline
```
Workflow: .github/workflows/build.yml
Triggers: push to main, PR, manual dispatch
Runner: macos-14, Xcode 16.0
Steps:
  1. xcodegen generate (from project.yml)
  2. swift package resolve (Satin 13.0.0 + OCCTSwift 1.0.0)
  3. xcodebuild build (unsigned, Debug, iOS)
  4. xcodebuild test (49 tests, iPad Simulator)
  5. xcodebuild archive + exportArchive (unsigned .ipa)

Artifacts:
  - AppForgeStudio-iOS (.app)
  - AppForgeStudio-iOS-IPA (.ipa, manual dispatch only)
```

## Dependencies

| Package | Version | Purpose | Size |
|---------|---------|---------|------|
| Satin (Hi-Rez) | 13.0.0 | Metal/Swift 3D rendering | ~2 MB |
| OCCTSwift (gsdali) | 1.0.0+ | B-rep CAD kernel (Open CASCADE) | ~190 MB iOS arm64 |

**Note:** Satin repo is archived (April 2025). Fork to `iwannatrip02-sys/Satin` for long-term maintenance.

## Requirements

- Xcode 16.0+
- Swift 6.1+
- iOS 17.0+ deployment target (iPad only)
- macOS runner for CI (GitHub Actions)
- 10+ GB free on runner (OCCTSwift xcframework is large)

## Limitations (Free Pipeline)

| Limitation | Detail |
|-----------|--------|
| App expires | 7 days (Sideloadly auto-refresh) |
| Max apps | 3 simultaneously on iPad |
| No push notifications | Free Apple ID limitation |
| No iCloud | Free Apple ID limitation |
| No App Store | Requires $99/year Apple Developer |
| No TestFlight | Requires Apple Developer |
| Unsigned .ipa | Must re-sign with Sideloadly on Windows |

## Production Pipeline (requires Apple Developer $99/yr)

```
GitHub Actions → xcodebuild archive (signed)
→ fastlane upload to TestFlight
→ App Store Connect review
→ App Store release
```

Add these GitHub Secrets:
- `APPSTORE_CONNECT_API_KEY`
- `MATCH_PASSWORD` (fastlane match)
- `APPLE_TEAM_ID`
