# Video Screener Project Instructions

## Overview
Video Screener is a macOS native SwiftUI application built using Swift Package Manager (SPM). It browses video files, parses metadata locally via `AVFoundation`, extracts mock C2PA Content Credentials, and calls Vertex AI to generate intelligent summaries and tags.

## Architecture & Nuances
- **Tech Stack:** SwiftUI (macOS 14+), SwiftData (`VideoMetadata`), AVKit.
- **Vertex AI Integration:** Uses the standard `/v1/projects/.../locations/.../publishers/google/models/[MODEL]:generateContent` endpoint in `VertexClient.swift` because standard models (like `gemini-3.1-flash-lite`) are currently rejected by the experimental `/interactions` endpoint. Configured via `@AppStorage` settings.
- **Content Credentials (C2PA):** The official `contentauth/c2pa-ios` v0.0.9 SPM binary does not contain a macOS slice. Do not attempt to link it directly. The project uses a native Swift `MockC2PAReader` to simulate extraction for UI purposes.
- SwiftData Persistence: The app uses `@Model` to persist Gemini summaries, comments, and technical metadata.
  - **Important:** The app uses `VideoMigrationPlan` to automatically handle schema evolutions. If you change `VideoMetadata.swift`, ensure you bump the version and add the stage to the migration plan.

## Build and Run
- Always use the provided `Makefile`. Do not rely solely on `swift build` or `swift run` for the final test, as the application requires a proper `.app` wrapper to present menus and settings.
- `make build`: Compiles the binary, copies it to `Screener.app/Contents/MacOS`, copies SPM resource bundles (`*.bundle`) to `Contents/Resources/`, and copies `Assets/Info.plist` and `Assets/AppIcon.icns`.
- `make run`: Builds and launches `Screener.app`.
- `make reset-db`: Clears the local SwiftData stores.
- **Linting & Searching:** Before running code analysis tools (like SwiftLint) or performing workspace-wide text searches, always run `make clean` first. This removes the hidden `.build/` directory, preventing false positives from lingering legacy SPM checkouts (like `c2pa-ios`).

## App Assets
- `AppIcon.icns` must be listed in `Info.plist` under the `CFBundleIconFile` key.
- If replacing the app icon, run `touch Screener.app` after the build to force macOS LaunchServices to flush the icon cache.
