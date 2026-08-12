# AGENTS.md

## Cursor Cloud specific instructions

### Product
This repository is a single **Flutter** application named `MUD` — an Italian-language marketplace app (compra = buy / vendi = sell). The UI lives entirely under `lib/` (screens, widgets, models). All data is in-memory mock data (`lib/data/mock_data.dart` + `lib/app_state.dart`); there is no backend, database, or auth.

### Toolchain
- Flutter **3.44.9** (stable) / Dart **3.12.2** is installed at `~/flutter` and added to `PATH` via `~/.bashrc`. This exactly matches the SDK constraint in `pubspec.yaml` (`^3.12.2`) and the pinned engine revision in `.metadata`.
- The startup update script runs `flutter pub get`, so dependencies are refreshed automatically. You normally do not need to install anything.

### Lint / Test / Build / Run
- Lint: `flutter analyze` (currently reports only 5 pre-existing info-level lints, exit 0).
- Test: `flutter test` — there is **no `test/` directory**, so this reports "Test directory not found" and exits 0. Nothing to run until tests are added.
- Run (web, this is the working path): `flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`, then open `http://localhost:8080` in the desktop Chrome. `flutter run -d chrome` also works.

### Non-obvious gotchas
- **Linux desktop target is not set up.** `flutter doctor` flags missing `ninja-build` and `libgtk-3-dev`; running `-d linux` will fail unless those system libs are installed. Prefer the **web/Chrome** target for demos and manual testing.
- **State is in-memory only.** Creating/editing/deleting a listing updates `AppState` at runtime; reloading the browser resets everything back to the mock data. Do not expect created listings to persist across a page reload.
- In web **debug** mode, closing a dialog (e.g. after "Crea annuncio") can cause a brief white repaint before the list re-renders — this is normal Flutter web debug rendering, not a crash.
