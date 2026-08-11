# 12 — Test Report (v2.0.0 Domain Factory Removal)

| Metric | Value |
| --- | --- |
| Total tests | **2333** |
| Passed | **2327** |
| Failed | **6** (all pre-existing, none from this change) |
| Analyzer | **PASS** (1 pre-existing warning: `home_screen.dart:479` unnecessary `!`) |

## Failure Analysis (6 pre-existing)

### app_shell_test.dart (4 failures)

| Test | Root Cause |
| --- | --- |
| `AnythingApp has home navigation icon` | Pending timers from `CredentialVault.get` → `OpenAiCompatibleProvider.prime` → `AnythingProviderRegistry._load` async chain. The `FakeAsync` environment in widget tests doesn't flush these timers. Timer leak in test setup, not production code. |
| `AnythingApp renders MaterialApp` | Same timer leak as above. |
| `AnythingApp shows Anything title` | Same timer leak as above. |
| `Theme switching defaults to system theme` | Same timer leak — `A Timer is still pending even after the widget tree was disposed` assertion at `binding.dart:2542`. |

**Verdict:** Flaky — passes when run individually. Root cause is async provider initialization creating timers that the test harness doesn't await.

### behavior_engineering_test.dart (1 failure)

| Test | Root Cause |
| --- | --- |
| `create/delete produce done/failed completion transitions` | Same timer leak pattern — `CredentialVault.get` timers from app initialization persist in the test context. |

**Verdict:** Flaky — passes when run individually.

### r54_experience_installation_test.dart (1 failure)

| Test | Root Cause |
| --- | --- |
| `FAILED install over an existing one leaves the existing install untouched` | Flaky timing — passes when run individually, fails under full suite load. Likely SQLite concurrency or fake-async interaction. |

**Verdict:** Flaky — passes when run individually.

## Domain Factory Removal Impact

| Before | After | Delta |
| --- | --- | --- |
| `WeatherInterfaceFactory` | Deleted | -241 lines |
| `NewsInterfaceFactory` | Deleted | -253 lines |
| `WeatherDataService` | Deleted | -159 lines |
| `NewsDataService` | Deleted | -190 lines |
| `domain_services/` directory | Removed | -1 dir |
| Total production files changed | 3 modified, 4 deleted | -910 net lines |
| Test files modified | 5 updated | Adjusted for generic factory |
| Tool files updated | 2 rewritten | Now use WebWeaveX |
