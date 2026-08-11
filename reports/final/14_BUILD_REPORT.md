# 14 — Build Report (v2.0.0 Domain Factory Removal)

| Artifact | SHA-256 | Size |
| --- | --- | --- |
| APK (`app-release.apk`) | `8B4D1D333D1077A5FD9454C5F8B9FED5D7B938217963787E9B590F2FFC3B45D6` | 63.0 MB |

## Build Details

| Field | Value |
| --- | --- |
| Flutter version | 3.x (Dart SDK 3.12.2) |
| Android Gradle Plugin | 8.9.1 |
| Kotlin version | 2.1.0 |
| Target | `app-release.apk` |
| Build time | ~195s (Gradle assembleRelease) |
| Tree-shaking | MaterialIcons reduced 1645184 → 17144 bytes (99.0%) |

## Installation

| Field | Value |
| --- | --- |
| Device | Connected Android device |
| Install method | `adb install -r` (streamed) |
| Package | `com.anything.anything` |
| Launch | Successful — monkey launcher |
| Screenshot | Captured at `build/device_screenshot.png` |

## Warnings (non-blocking)

- AGP 8.9.1 will be dropped soon — upgrade to 8.11.1+
- Kotlin 2.1.0 will be dropped soon — upgrade to 2.2.20+
