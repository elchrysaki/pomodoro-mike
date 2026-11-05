# Mike

A free, open-source, native macOS Pomodoro buddy. It lives in a movable floating panel, animates through four stick-figure states, and includes a configurable session dashboard.

## Included

- Movable, always-on-top floating timer
- Hover-to-reveal close button that fully quits the app and camera guard
- Studying, checking-in, celebrating, and angry stick-figure animations
- Click-to-open quick controls: pause/start, repeat, skip, custom timer, dashboard
- Custom focus, short-break, long-break, and session-count settings
- Finite or continuously repeating cycles
- Native macOS notification sound at phase changes
- Optional on-device camera guard using Apple Vision
- Apple-style translucent glass UI
- No account, cloud service, analytics, or paid API
- Menu-bar control for start/pause, reopening the widget, and the dashboard

## Camera guard

Phone guard is deliberately opt-in. Apple Vision analyzes frames in memory and the app never saves or uploads them. Without shipping a large third-party object-detection model, the included beta detects a **phone-like posture**: a visible hand held near the face for at least three seconds. Looking toward the display and downward reading posture are also classified locally.

You can disable it at any time from the dashboard or from the warning panel. macOS shows its standard camera permission prompt the first time it is enabled.

## Build and run

Requires macOS 14 or later and Apple Command Line Tools.

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open .build/Mike.app
```

The build script creates an ad-hoc signed app at `.build/Mike.app`. To run the timer-sequence checks (including on Command Line Tools installations without XCTest):

```sh
chmod +x scripts/check-logic.sh
./scripts/check-logic.sh
```

Because this local build is not notarized, macOS may ask you to confirm opening it the first time.

## Privacy

All preferences are stored in `UserDefaults`. Camera processing remains on the Mac. No network entitlement or dependency is included.
