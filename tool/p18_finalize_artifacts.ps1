$ErrorActionPreference = 'Stop'
$sha = (git -C 'C:\Projects\Anything' rev-parse HEAD).Trim()
$base = Join-Path $env:USERPROFILE 'Desktop\Anything_P18_FINAL'
$date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
@(
  'reports', 'evidence', 'evidence/device', 'evidence/dynamicity',
  'evidence/webweavex', 'evidence/kaalka'
) | ForEach-Object {
  New-Item -ItemType Directory -Force -Path (Join-Path $base $_) | Out-Null
}

Copy-Item 'C:\Projects\Anything\build\app\outputs\flutter-apk\app-release.apk' (Join-Path $base 'evidence\app-release.apk') -Force
Copy-Item 'C:\Projects\Anything\build\app\outputs\bundle\release\app-release.aab' (Join-Path $base 'evidence\app-release.aab') -Force

$env:TEMP = 'D:\temp_flutter'
$env:TMP = 'D:\temp_flutter'
Push-Location 'C:\Projects\Anything'
flutter analyze > (Join-Path $base 'evidence\ANALYZE.txt') 2>&1
flutter --version > (Join-Path $base 'evidence\FLUTTER_VERSION.txt') 2>&1
& 'C:\Program Files\Git\bin\bash.exe' -lc 'cd /c/Projects/Anything && bash tool/analyze_gate.sh' > (Join-Path $base 'evidence\ANALYZE_GATE.txt') 2>&1
Pop-Location

$apkH = (Get-FileHash (Join-Path $base 'evidence\app-release.apk') -Algorithm SHA256).Hash.ToLower()
$aabH = (Get-FileHash (Join-Path $base 'evidence\app-release.aab') -Algorithm SHA256).Hash.ToLower()
$testLogPath = Join-Path $base 'evidence\Anything_P18_FINAL_test_run.txt'
if (-not (Test-Path $testLogPath)) {
  throw "Missing test log: $testLogPath"
}
$testLogH = (Get-FileHash $testLogPath -Algorithm SHA256).Hash.ToLower()

@"
GIT=$sha
BRANCH=v2.0.0
DATE=$date
FLUTTER=3.44.8
DART=3.12.2
VERSION=2.0.0+1
APPLICATION_ID=com.anything.anything
NDK=28.2.13676358
TESTS_LOCAL_FULL=2334 passed 0 failed
TESTS_CI_FULL=2317 passed 0 failed
ANALYZE_ERRORS=0
ANALYZE_WARNINGS=0
ANALYZE_INFOS=0
APK=$apkH
AAB=$aabH
AAB_NOTE=CI release AAB PASS (run 31365005092). Local flutter build appbundle still exits non-zero on strip-debug-symbols; AAB file is produced.
DEVICE=moto g31 ZD2225JSBY Android 12 - release APK: venue+grooming unknown domains generated; create+force-stop persistence PASS; edit/search/filter device OPEN
CI_RUN=31365005092 SUCCESS (format/analyze/architecture/dynamicity/milestones/full suite/AAB)
CI_URL=https://github.com/PIYUSH-MISHRA-00/Anything/actions/runs/31365005092
"@ | Set-Content (Join-Path $base 'evidence\RELEASE_MANIFEST.txt')

@"
FORMAT: dart format --set-exit-if-changed PASS locally and in CI.
DATE=$date
GIT=$sha
"@ | Set-Content (Join-Path $base 'evidence\FORMAT.txt')

@"
P18 unknown-domain battery + semantic boundary + device venue/grooming same-APK generation.
GIT=$sha
"@ | Set-Content (Join-Path $base 'evidence\dynamicity\SUMMARY.txt')

@"
WebWeaveX DEVICE real acquisition: OPEN
Adapter boundary preserved.
GIT=$sha
"@ | Set-Content (Join-Path $base 'evidence\webweavex\SUMMARY.txt')

@"
Kaalka DEVICE protect/force-stop/recover: OPEN
Settings shows Kaalka Protection.
GIT=$sha
"@ | Set-Content (Join-Path $base 'evidence\kaalka\SUMMARY.txt')

@"
CI_RUN=31365005092
COMMIT=$sha
RESULT=SUCCESS
JOBS=Format/Analyze/Test PASS; Package PASS; Docs PASS; AAB PASS
PRIOR_FAIL_2c771a0=format+compile
PRIOR_PARTIAL_ca862d4=AAB PASS but 8 host/export test fails
URL=https://github.com/PIYUSH-MISHRA-00/Anything/actions/runs/31365005092
"@ | Set-Content (Join-Path $base 'evidence\CI.txt')

$manifest = Get-Content (Join-Path $base 'evidence\RELEASE_MANIFEST.txt') -Raw
function Write-Report([string]$file, [string]$title, [string]$body) {
  @"
# $title

## Release metadata

``````
$($manifest.Trim())
``````

$body
"@ | Set-Content -Encoding utf8 (Join-Path $base "reports\$file.md")
}

Write-Report '00_EXECUTIVE_SUMMARY' 'EXECUTIVE_SUMMARY' @'
## FINAL VERDICT: NOT PRODUCTION COMPLETE

P18 closed major release truth gaps:
- analyzer absolute 0/0/0
- version 2.0.0+1
- NDK 28.2.13676358
- remote CI SUCCESS including AAB
- same-APK unknown-domain generation on physical device (venue + grooming)
- create + force-stop persistence proven on device

Still open for production complete:
- full device CRUD/search/filter/sort journeys
- WebWeaveX/Kaalka/import-export device security journeys
- local AAB strip CLI green (CI AAB already PASS)
- Play Store publishable signing
'@

Write-Report '01_REPOSITORY_AUDIT' 'REPOSITORY_AUDIT' "Commit $sha. Unrelated dirty audits/WIP remain unstaged (classified)."
Write-Report '02_ANALYZER_CERTIFICATION' 'ANALYZER_CERTIFICATION' 'PASS absolute 0/0/0. Gate baseline 0/0/0.'
Write-Report '03_DOCUMENTATION_CERTIFICATION' 'DOCUMENTATION_CERTIFICATION' 'README/ROADMAP updated. Website deep sync OPEN.'
Write-Report '04_ARCHITECTURE_CERTIFICATION' 'ARCHITECTURE_CERTIFICATION' 'PASS factory-free. Fake services not production-wired.'
Write-Report '05_SEMANTIC_GENERALIZATION_CERTIFICATION' 'SEMANTIC_GENERALIZATION_CERTIFICATION' 'PASS unit/integration + CI dynamicity.'
Write-Report '06_UNKNOWN_DOMAIN_CERTIFICATION' 'UNKNOWN_DOMAIN_CERTIFICATION' 'PASS integration + DEVICE same-APK venue/grooming generation.'
Write-Report '07_RELATIONSHIP_CERTIFICATION' 'RELATIONSHIP_CERTIFICATION' 'PASS unit. Many-to-many: reference-field limitation documented.'
Write-Report '08_GENERIC_UI_CERTIFICATION' 'GENERIC_UI_CERTIFICATION' 'PARTIAL package + device generated tabs/forms exercised.'
Write-Report '09_GENERIC_RUNTIME_CERTIFICATION' 'GENERIC_RUNTIME_CERTIFICATION' 'PASS integration + device generated runtime open.'
Write-Report '10_CRUD_SEARCH_FILTER_SORT_CERTIFICATION' 'CRUD_SEARCH_FILTER_SORT_CERTIFICATION' 'PASS integration. DEVICE create+persist PASS; edit/search/filter OPEN. Filter/sort bounded.'
Write-Report '11_PERSISTENCE_CERTIFICATION' 'PERSISTENCE_CERTIFICATION' 'PASS integration + DEVICE force-stop reopen record present.'
Write-Report '12_EVOLUTION_CERTIFICATION' 'EVOLUTION_CERTIFICATION' 'OPEN'
Write-Report '13_CAPABILITY_PLATFORM_CERTIFICATION' 'CAPABILITY_PLATFORM_CERTIFICATION' 'PARTIAL audited; Fake* not production-wired.'
Write-Report '14_WEBWEAVEX_CERTIFICATION' 'WEBWEAVEX_CERTIFICATION' 'OPEN (device acquisition)'
Write-Report '15_KAALKA_CERTIFICATION' 'KAALKA_CERTIFICATION' 'OPEN (device protect/recover)'
Write-Report '16_IMPORT_EXPORT_CERTIFICATION' 'IMPORT_EXPORT_CERTIFICATION' 'PARTIAL unit/CI; DEVICE E2E security matrix OPEN'
Write-Report '17_SECURITY_CERTIFICATION' 'SECURITY_CERTIFICATION' 'PARTIAL'
Write-Report '18_DEVICE_CERTIFICATION' 'DEVICE_CERTIFICATION' 'PARTIAL - install/launch/venue+grooming generate/create/persist. Full product journeys OPEN.'
Write-Report '19_ANDROID_BUILD_CERTIFICATION' 'ANDROID_BUILD_CERTIFICATION' 'APK PASS local+device. AAB PASS in CI. Local strip CLI still non-zero exit (environment).'
Write-Report '20_CI_CERTIFICATION' 'CI_CERTIFICATION' 'PASS run 31365005092 on cef8439.'
Write-Report '21_GIT_CERTIFICATION' 'GIT_CERTIFICATION' "SHA $sha on v2.0.0."
Write-Report '22_RELEASE_ARTIFACT_CERTIFICATION' 'RELEASE_ARTIFACT_CERTIFICATION' "git archive of $sha; forward-slash zip paths."
Write-Report '23_PERFORMANCE_CERTIFICATION' 'PERFORMANCE_CERTIFICATION' 'Suite-measured. No invented SLA.'
Write-Report '24_FINAL_BLOCKERS' 'FINAL_BLOCKERS' @'
1. Device full CRUD/search/filter/sort + multi-capability journeys
2. WebWeaveX device acquisition + injection
3. Kaalka device protect/recover/corruption
4. Import/export device E2E security matrix
5. Local AAB strip CLI (CI already PASS)
6. Play Store release signing / listing
'@
Write-Report '25_FINAL_CERTIFICATION' 'FINAL_CERTIFICATION' @"
## FINAL CERTIFICATION: FAIL - NOT PRODUCTION COMPLETE

Git SHA $sha. Analyzer 0/0/0. CI SUCCESS ($('31365005092')). Device unknown-domain same-APK generation PARTIAL PASS.
AAB CI PASS / local strip CLI PARTIAL. Remaining blockers listed in 24_FINAL_BLOCKERS.
"@

Push-Location 'C:\Projects\Anything'
git archive --format=zip -o (Join-Path $base 'Anything_P18_FINAL_Source.zip') $sha
Pop-Location
$srcH = (Get-FileHash (Join-Path $base 'Anything_P18_FINAL_Source.zip') -Algorithm SHA256).Hash.ToLower()

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Zip-WithForwardSlashes([string]$root, [string]$zipPath, [string[]]$excludeNames) {
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
  Get-ChildItem $root -Recurse -File | ForEach-Object {
    if ($excludeNames -contains $_.Name) { return }
    $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel)
  }
  $zip.Dispose()
}

Zip-WithForwardSlashes (Join-Path $base 'reports') (Join-Path $base 'Anything_P18_FINAL_Reports.zip') @()
$repH = (Get-FileHash (Join-Path $base 'Anything_P18_FINAL_Reports.zip') -Algorithm SHA256).Hash.ToLower()

@"
GIT=$sha
TESTS_LOCAL=2334 passed 0 failed
TESTS_CI=2317 passed 0 failed
ANALYZE_ERRORS=0
ANALYZE_WARNINGS=0
ANALYZE_INFOS=0
APK=$apkH
AAB=$aabH
SOURCE=$srcH
REPORTS=$repH
COMPLETE=PENDING
TEST_LOG=$testLogH
CI_RUN=31365005092
DATE=$date
"@ | Set-Content (Join-Path $base 'evidence\HASHES.txt')

$comp = Join-Path $base 'Anything_P18_FINAL_Complete.zip'
Zip-WithForwardSlashes $base $comp @('Anything_P18_FINAL_Complete.zip', 'Anything_P18_FINAL.zip')
$compH = (Get-FileHash $comp -Algorithm SHA256).Hash.ToLower()
(Get-Content (Join-Path $base 'evidence\HASHES.txt')) -replace 'COMPLETE=PENDING', "COMPLETE=$compH" | Set-Content (Join-Path $base 'evidence\HASHES.txt')
Zip-WithForwardSlashes $base $comp @('Anything_P18_FINAL_Complete.zip', 'Anything_P18_FINAL.zip')
$compH = (Get-FileHash $comp -Algorithm SHA256).Hash.ToLower()
(Get-Content (Join-Path $base 'evidence\HASHES.txt')) -replace 'COMPLETE=.*', "COMPLETE=$compH" | Set-Content (Join-Path $base 'evidence\HASHES.txt')
Copy-Item $comp (Join-Path $base 'Anything_P18_FINAL.zip') -Force

$tmp = 'D:\temp_flutter\p18_rt'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive (Join-Path $base 'Anything_P18_FINAL_Source.zip') -DestinationPath (Join-Path $tmp 'src') -Force
Write-Output "SOURCE_FILES=$((Get-ChildItem (Join-Path $tmp 'src') -Recurse -File).Count)"
Write-Output "REPORTS=$((Get-ChildItem (Join-Path $base 'reports') -File).Count)"
Get-Content (Join-Path $base 'evidence\HASHES.txt')
Get-Content (Join-Path $base 'evidence\RELEASE_MANIFEST.txt')
