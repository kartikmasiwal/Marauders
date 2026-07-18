# Marauders

Marauders is a SwiftUI monument companion that turns demo District bookings into interactive, chapter-based tours.

Built as a local-first prototype, the app requires no API keys or backend services.

## Features

- Demo phone and OTP authentication (`123456`), plus a local Google demo sign-in
- Three tour bookings: Taj Mahal, National War Memorial, and Zomato Farmhouse
- Local illustrated maps with panning, zooming, chapter hotspots, and glass information cards
- Spoken in-app audio guides with chapter selection, playback, and progress controls
- In-app camera preview, permission flow, capture control, and AR-ready overlay UI
- Responsive native SwiftUI layouts and Dynamic Type-compatible text
- Local mock services and data with no backend or API keys

## Requirements

- Xcode 26 or later
- iOS 18 or later
- A physical iPhone is recommended for camera testing

## Demo Access

1. Enter any 10-digit Indian phone number.
2. Use OTP `123456`.
3. Alternatively, select **Continue with Google** to use the local demo account.

Authentication, tickets, monument content, and audio-guide metadata are mock implementations suitable for demos and development.

## Build

Open `Marauders.xcodeproj` in Xcode and run the `Marauders` scheme, or use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Marauders.xcodeproj -scheme Marauders \
  -destination 'generic/platform=iOS Simulator' build
```

## Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Marauders.xcodeproj -scheme Marauders \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test
```

## Architecture

Feature modules live under `Marauders/Features`; shared theme, models, navigation, and services live under `Marauders/Core`. Authentication and content are intentionally local demo implementations that can be replaced behind service boundaries.

```text
Marauders/
├── App/                 App entry point and root flow
├── Core/                Design system, models, navigation, and services
├── Features/            Authentication, bookings, maps, audio, camera, profile
├── Resources/           Asset catalog, bundled maps, localization, and audio
MaraudersTests/          Swift Testing unit tests
MaraudersUITests/        XCTest UI flows
Documentation/           Design implementation notes
```

## Camera and AR

The Scan tab uses an embedded `AVCaptureSession`, including camera permission and denied-access handling. The current interface provides an AR-ready camera overlay and capture control; advanced world tracking and monument recognition are intentionally left for a future backend/content phase.

## Verification

The app has been built successfully with Xcode 26 against the iOS 26 simulator SDK. Unit tests cover demo authentication, monument data, and hotspot bounds. The UI test verifies Google demo login and access to the tour list.
