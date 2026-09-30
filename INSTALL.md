# TACTIX NEO — Visual Phase 1 (current-source edition)

**Based on the latest `TACTIX_FINAL_SOURCE.zip` (29 September 2026, approximately 105 MB).** This ZIP is an incremental patch, not a replacement application.

## Included
- A new fictional, offline-painted Strategy hero on the home screen linking to the existing working Strategy screen.
- Real **locally loaded** training-session and active-assignment counters. These are existing home-screen data, not a new cloud query.
- A calmer home-screen layout with three immediately visible core metrics and four everyday destinations: Training, Strategy Platform (when signed in to the server), Assignments, and AI Chat. The Strategy hero provides the simulator entry.
- Additional scenarios, demo, instructor legacy tools, environmental dashboard, achievements and charts remain reachable under **«Показать все инструменты и аналитику»**; existing desktop side navigation is unchanged.
- Functional assignments shortcut in the header in place of the previous placeholder notification.
- Shared Material 3 navigation and floating-snackbar styling, plus a widget test for the new hero.

**Not changed:** backend, sync queue, database schema, Strategy engine, scenario data, stored records, instructor services, or Android signing. The AI chat and other legacy screens are not redesigned in this first incremental patch.

## Install on Windows
1. **Back up** your current `ai_trainer_mobile` folder or commit local changes.
2. Unzip this archive directly into the root of that folder, keeping the `lib/` and `test/` structure. Confirm replacement of only `lib/screens/home/home_screen.dart` and `lib/app/theme.dart`; the other two Dart files are new.
3. In PowerShell:

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile"
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Check widths around 360px, 390px, tablet and desktop. The Android build requires the existing configured Flutter environment. If you made additional changes to `home_screen.dart` or `theme.dart` **after** the supplied 29 September source archive, merge instead of blindly replacing.

## Verification / limitations
Source identity was checked against the current uploaded ZIP; the modified Dart files received static structural checks and the ZIP integrity check passed. **This environment does not include Dart or Flutter.** Flutter analyzer, widget tests, physical-device testing and app builds must be run locally. Treat this as a test-ready development patch rather than a verified release.
