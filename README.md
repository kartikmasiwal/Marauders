# Marauders

Marauders is an offline-first SwiftUI monument companion that turns demo District bookings into interactive map, AR, and voice-guided tours.

Built as a local-first prototype, the app requires no API keys or backend services.

## Features

- Demo phone and OTP authentication (`123456`), plus a local Google demo sign-in
- Three tour bookings: Taj Mahal, National War Memorial, and Zomato Farmhouse
- Downloadable ZIP tour packages decoded from the deployed backend contract
- Local illustrated maps driven by package checkpoint order and normalized coordinates
- ARKit image tracking that resolves printed targets to local audio nuggets
- Debounced offline audio playback that tolerates brief target occlusion
- Persistent SwiftData progress for checkpoint state and secrets-found counts
- English/Hindi package selection, on-device GPS checkpoint resolution, and live voice Q&A
- Responsive native SwiftUI layouts and Dynamic Type-compatible text
- Local mock services and data with no backend or API keys

## Requirements

- Xcode 26 or later
- iOS 18 or later
- A physical ARKit-capable iPhone is required for image-tracking verification

## Demo Access

1. Enter any 10-digit Indian phone number.
2. Use OTP `123456`.
3. Alternatively, select **Continue with Google** to use the local demo account.

Authentication, tickets, monument content, and audio-guide metadata are mock implementations suitable for demos and development.

## Backend Configuration

The app defaults to `http://127.0.0.1:8000`, which reaches a backend running on the same Mac from the simulator. For a physical iPhone, provide the Mac's LAN address and app key without committing either value:

```sh
MARAUDERS_API_BASE_URL=http://192.168.1.10:8000 \
MARAUDERS_APP_KEY=your-hand-carried-key \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Marauders.xcodeproj -scheme Marauders \
  -destination 'generic/platform=iOS' build
```

`Secrets.xcconfig.example` documents the equivalent local Xcode values. `Secrets.xcconfig` is ignored by Git. Package and health endpoints are open; only `/ask` receives `X-App-Key`.

## Offline Package

`Marauders/Resources/Packages/taj_mahal.zip` is bundled for deterministic demos. It contains:

```text
tour.json
audio/*.mp3
targets/*.jpg
```

The package is unzipped to Application Support and validated before the tour opens. Every checkpoint must contain a nugget and every localized audio and target path must resolve on disk. The core map, AR recognition, audio playback, and progress flow make no network calls.

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

Feature modules live under `Marauders/Features`; shared theme, exact backend models, navigation, package storage, location, Q&A, and session services live under `Marauders/Core`.

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

The Scan tab uses `ARImageTrackingConfiguration`. Package target JPGs become `ARReferenceImage` instances at runtime; recognition selects the matching nugget and drives the debounced local audio state machine. On the simulator, a target picker exercises the same selection and playback path.

The microphone records a 16 kHz mono M4A question, POSTs it to `/ask`, and plays the returned base64 audio without blocking the UI. Missing configuration and network failures surface retryable messages.

## Verification

The app builds with the installed Xcode 26 and iOS 26 SDK. The requested iOS 27 SDK is not currently installed, so `FoundationModelsAnswerEngine` is a protocol-compatible stub; the primary Azure engine is complete. Tests cover contract JSON decoding, package installation/path validation, localization fallback, audio timing, authentication, and the bundled tour launch flow.
