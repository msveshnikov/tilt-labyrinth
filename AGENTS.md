# AGENTS.md

Notes for coding agents working on **Tilt Labyrinth**, a Godot 4.7 tilt-maze game written in GDScript only. Read `README.md` for gameplay, controls and the level format.

## Where things are

| What | Where |
|---|---|
| Source code | `C:\My-progs\Godot\labyrinth` |
| Git repo | https://github.com/msveshnikov/tilt-labyrinth (branch `main`) |
| Live web build | https://severance.lol/2/ |
| Android APK (download) | https://severance.lol/2/TiltLabyrinth.apk |
| Server folder | `ubuntu@severance.lol:/var/www/severance/2/` (nginx, HTTPS) |
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
- `scripts/autoload/`: `settings.gd` (user settings), `tilt_input.gd` (sensor, browser and keyboard input, calibration), `sfx.gd`, `progress.gd` (unlocks and stars).
- `scripts/ui/`: `screens.gd` (menus, level select, a 5-column grid), `hud.gd`, `touch_joystick.gd`, `ui_theme.gd`, `star_row.gd`.
- UI text is in Russian, and code comments are in English.

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
"$G" --headless --export-debug "Android" build/android/TiltLabyrinth.apk
scp build/web/* build/android/TiltLabyrinth.apk ubuntu@severance.lol:/var/www/severance/2/
```

- The Android build is debug-signed (no release keystore), arm64 only.
- **Android tilt:** `project.godot` must keep `input_devices/sensors/enable_accelerometer` / `enable_gravity` / `enable_gyroscope = true`. Godot 4.3+ disables the sensors on Android by default, and the APK then reads zero tilt. No runtime permission is needed.
- **Web tilt** needs HTTPS. iOS also needs the in-page permission prompt, which `tilt_input.gd` handles through `JavaScriptBridge`.

## Conventions

- Godot 4.7, Compatibility renderer, Jolt physics, 120 Hz physics ticks.
- Don't commit `.godot/`, `build/` or `android/` (see `.gitignore`).
- After changing gameplay, run the headless smoke test, rebuild both targets and redeploy. Then check https://severance.lol/2/ at phone size (450×800).
