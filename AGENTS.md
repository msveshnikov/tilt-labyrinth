# AGENTS.md

Notes for coding agents working on **Tilt Labyrinth**, a Godot 4.7 tilt-maze game written in GDScript only. Read `README.md` for gameplay, controls and the level format.

## Where things are

| What | Where |
|---|---|
| Source code | `C:\My-progs\Godot\labyrinth` |
| Git repo | https://github.com/msveshnikov/tilt-labyrinth (branch `main`) |
| Live web build | https://maxims.top/labyrinth/ |
| Android APK (download) | https://maxims.top/labyrinth/TiltLabyrinth.apk |
| Google Play | «Лабиринт: наклони и катай», package `com.maxsoft.tiltlabyrinth`, Play Console app id 4974986460613496436 (dev 5957945224586801272). Created 2026-11-23; production release 2 (1.1) to 178 countries plus ru-RU/en-US listings sent for review on 2026-11-23 |
| Play upload key | `~/.android/tiltlabyrinth-upload.jks` (alias `tiltlabyrinth`, password in `tiltlabyrinth-upload.txt` beside it). Godot reads it from `.godot/export_credentials.cfg` (preset.0 APK and preset.2 Play). Never commit it. |
| Privacy policy | `store/privacy.html` → https://maxims.top/labyrinth/privacy.html |
| Server folder | `ubuntu@severance.lol:/var/www/maxims/labyrinth/` (nginx, HTTPS) |
| Godot binary (Windows) | `C:\Users\msves\OneDrive\Рабочий стол\Godot_v4.7.2-stable_win64.exe` |
| Android SDK / adb | `C:\Users\msves\AppData\Local\Android\Sdk` (`platform-tools/adb`) |
| Local build output | `build/web/`, `build/android/` (git-ignored) |
| Player saves | `user://settings.cfg`, `user://progress.cfg` |

## Code map

- `scenes/main.tscn` is the only scene. Everything else is built in code.
- `scripts/main.gd` holds the game loop, level start and win, and fits the camera to the board size.
- `scripts/board.gd` turns the grid into walls, floor, holes and pockets (`POCKET_CHARS`).
- `scripts/ball.gd` holds ball physics, capture and falling. Colours and symbols are in `INFO`.
- `scripts/level_loader.gd` counts `levels/level_NN.json` files on its own, so a new file just shows up in the game.
- Controls: on touch devices `Settings.control` is `"tilt"` or `"joystick"`. The «Управление» row (`Screens._add_control_choice`) sits in the main menu, the pause menu and settings. `TiltInput.wants_joystick()` shows the joystick when it is chosen or when the sensor is silent. `main.gd` then fits the board above the joystick (`_joystick_room`).
- `scripts/autoload/`: `settings.gd` (user settings), `tilt_input.gd` (sensor, browser and keyboard input, calibration), `sfx.gd`, `progress.gd` (unlocks and stars).
- `scripts/ui/`: `screens.gd` (menus, level select, a 5-column grid), `hud.gd`, `touch_joystick.gd`, `ui_theme.gd`, `star_row.gd`.
- `Screens._root` must stay `MOUSE_FILTER_IGNORE`. It sits on layer 10 over the HUD, and if it blocks the mouse, the in-game buttons stop working.
- UI supports Russian and English. Keep English translations in `translations/en.po` and code comments in English.
- Icons: `python tools/gen_icons.py` writes `icon.svg` (project icon and favicon) and `icons/*.svg` (Android adaptive layers and launch splash, full-bleed iOS variant, boot splash). The export presets use the PNG renders in `icons/`, so re-render them after changing the art. `icons/` has a `.gdignore`, so the PNGs aren't packed into the game.

## Levels

- `python tools/gen_levels.py` regenerates **all** `levels/*.json` from the `LEVELS` table. It's deterministic, with one seed per row. Append rows to add levels. Don't reorder or change existing rows, or players' saved stars stop matching their levels.
- Difficulty is controlled by maze size (`mw`×`mh` cells, so the grid is `2w+1`×`2h+1`), the number of balls (max 4: r/b/g/y), the loop share (lower means fewer shortcuts and longer routes), and the number of holes.
- Keep mazes at 8×10 cells or smaller (17×21 grid) so balls stay readable on a portrait phone.
- `par` (the time for full stars) is computed by the generator from path lengths.

## Build and deploy

```sh
G="/c/Users/msves/OneDrive/Рабочий стол/Godot_v4.7.2-stable_win64.exe"
"$G" --headless --quit-after 300                      # smoke test: look for script errors
"$G" --headless --export-release "Web" build/web/index.html
"$G" --headless --export-release "Android" build/android/TiltLabyrinth.apk   # signed with the Play upload key
"$G" --headless --export-release "Android Play" build/play/TiltLabyrinth.aab   # Google Play (Gradle, target SDK 36)
scp build/web/* build/android/TiltLabyrinth.apk store/privacy.html ubuntu@severance.lol:/var/www/maxims/labyrinth/
```

- Both Android builds are release builds signed with the Play upload key, arm64 only. Never ship `--export-debug` APKs, because Play Protect warns about them. Bump `version/code` in BOTH Android presets for every build.
- The Gradle template lives in `android/build` (git-ignored). On a fresh checkout, add `--install-android-build-template` to the first Play export.
- **Android tilt:** `project.godot` must keep `input_devices/sensors/enable_accelerometer` / `enable_gravity` / `enable_gyroscope = true`. Godot 4.3+ disables the sensors on Android by default, and the APK then reads zero tilt. No runtime permission is needed.
- **Web PWA cache:** the export has a service worker (`progressive_web_app/enabled=true`). After a deploy, browsers run the old build once and switch to the new one on the next load. To test a deploy right away, unregister the service worker and clear `caches` in DevTools first.
- **Web tilt** needs HTTPS. iOS also needs the in-page permission prompt, which `tilt_input.gd` handles through `JavaScriptBridge`.

## Conventions

- Godot 4.7, Compatibility renderer, Jolt physics, 120 Hz physics ticks.
- Don't commit `.godot/`, `build/` or `android/` (see `.gitignore`).
- After changing gameplay, run the headless smoke test, rebuild both targets and redeploy. Then check https://maxims.top/labyrinth/ at phone size (450×800).

## Google Play

- Listing texts: `store/listing.md`. Graphics: `python tools/play_store.py` → `renders/play/` (icon 512, banner 1024×500, ru/en screenshots 1080×1920).
- Declarations: free game, category «Головоломки», no ads, no data collected, no login, no ad ID, no finance or health features, target audience 13+, IARC «Для всех» / PEGI 3, assets not marked as AI (game renders and code-generated icon). Contact: developer email + https://maxims.top/labyrinth/.
- Play warns that `android.hardware.screen.portrait` is required (portrait lock). For a tilt maze this is intended, so answer «Продолжить все равно».
- Store screenshots: `-- --storeshots` renders 7 shots at 1080x1920 (a borderless window, because a captioned one is clamped to the screen). The ru-RU listing holds them; en-US inherits them and only has its own banner.
- Update flow: bump `version/code` in both Android presets → export «Android Play» → Play Console → Production → Create release → upload the AAB → Next → Save → Publishing overview → send for review.
- The built-in browser can't pick files. Serve the folder from a local CORS server on 127.0.0.1, fetch the file as a blob, set it on the page's `input[type=file]` through `DataTransfer`, then dispatch `change`.
