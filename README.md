# Video Screener

Video Screener is a macOS native SwiftUI application built for developers, editors, and filmmakers to rapidly browse, analyze, and organize video files. It leverages SwiftData and Google Cloud Vertex AI to provide intelligent, offline-capable, and AI-driven video metadata extraction.

<img width="1977" height="1097" alt="Image" src="https://github.com/user-attachments/assets/2ef56291-62f9-46de-b3c3-4bef6ab10143" />

## Features

- **macOS HIG Layout**: Utilizes a fully compliant native SwiftUI `.inspector` pane for resizable, distraction-free analysis. Features a custom 3D Gemini-styled macOS app icon.
- **Hybrid Semantic Search**: Learn more about the vector embedding architecture in our [Hybrid Semantic Search Documentation](docs/hybrid-semantic-search.md).
- **SwiftData Persistence**: Video metadata, technical information, and custom comments are preserved locally on your machine automatically as you browse.
- **Auto-Cleanup**: The application automatically detects when video files have been deleted from your hard drive and purges their orphaned metadata from the database during directory refreshes to maintain optimal performance.
- **Content Credentials (C2PA) Native Integration**: Seamlessly detects and parses C2PA signatures and assertions (e.g., `c2pa.training-mining: notAllowed`) out of video manifests by natively bundling the `c2patool` Rust binary. Features a dedicated expandable modal detailing cryptographically signed provenance.
- **Background Extraction**: Automatically extracts visual and technical metadata via `AVFoundation` without blocking the UI:
  - Thumbnails / Poster Frames
  - Duration
  - Resolution and Aspect Ratios
  - Frame Rate (FPS)
  - Audio Track Detection
- **Gemini Video Analysis**: Connects directly to Google Cloud Vertex AI (`gemini-3.1-flash-lite`) to analyze video content, providing:
  - Concise Summaries
  - Topical Tags
  - Audio Transcripts
  - Color & Mood Assessment
  - Camera Motion Types
  - Content Safety Ratings
- **Multimodal Semantic Search**: Leverages Vertex AI's `gemini-embedding-2-preview` alongside Apple's on-device `NLEmbedding` to provide blazing fast, deep semantic search across text and visual data. Results are fully transparent, surfacing cosine similarity scores and offering an interactive, real-time configurable cutoff threshold in Settings. Learn more about the vector embedding architecture in our [Hybrid Semantic Search Documentation](docs/hybrid-semantic-search.md).
- **Environment & GCP Aware**: Manage your Google Cloud project, region, and model names effortlessly within the native macOS Settings (`Cmd+,`). Supports connecting to Production, Staging, and Autopush environments.

## Setup & Running

### 1. Prerequisites
Ensure you have Apple's Swift toolchain and the Google Cloud SDK (`gcloud` CLI) installed on your machine.

### 2. Authentication
The application natively leverages your Google Cloud credentials to authorize requests. You must be authenticated locally with Application Default Credentials (ADC):
```bash
gcloud auth login
gcloud auth application-default login
```

### 3. Build & Launch
You can use the provided `Makefile` to easily compile and package the application into a native macOS `.app` bundle:
```bash
make build   # Builds the release binary and packages Screener.app
make run     # Compiles and launches the app natively
make install # Installs the app to your /Applications directory
make clean   # Clean build artifacts and local bundles
```

### 4. Application Configuration
Upon launching the application for the first time, you **must configure your GCP settings**:
1. Open the application settings by navigating to **Video Screener > Settings...** in the macOS menu bar (or press `Cmd + ,`).
2. **Video Directory:** Specify the absolute path to the directory containing your videos (defaults to `~/Movies`). You can add multiple directories using the native macOS folder picker.
3. **Model Name:** Ensure the Vertex AI model is set correctly (defaults to `gemini-3.1-flash-lite`).
4. **GCP Project:** Enter your target Google Cloud Project ID. (If left blank, the app will attempt to dynamically resolve this using `gcloud config get-value project`).
5. **GCP Location:** Enter your target Vertex AI region (e.g., `us-central1`).

## Development & Schema Changes

If you modify the `VideoMetadata` model during development, you should update the `SchemaMigrationPlan` to handle the evolution. The application uses `VideoMigrationPlan.swift` to automatically migrate data between schemas without crashing or losing data. If you ever need a clean slate, you can still clear the database:
```bash
make reset-db
```

## C2PA Tool Dependency

This project natively executes the `c2patool` Rust binary to parse Content Credentials. A compiled version of this tool is bundled in `Sources/screener/Resources/c2patool`. 

If you clone this repository on a different architecture (e.g., an Intel Mac), you may need to replace this binary with one compiled for your system:
1. Download the latest `c2patool-universal-apple-darwin.zip` from the [contentauth/c2patool releases page](https://github.com/contentauth/c2patool/releases).
2. Extract the `c2patool` binary and replace the file at `Sources/screener/Resources/c2patool`.
3. Ensure it is executable: `chmod +x Sources/screener/Resources/c2patool`

## Releasing and Distribution

To distribute this macOS application so that others can download it from GitHub and run it without building from source, you must package and sign it:

1. **Build the Release App:** Run `make build` to generate the `Screener.app` bundle.
2. **Code Signing:** macOS requires apps to be signed. Use your Apple Developer ID:
   ```bash
   codesign --force --options runtime --sign "Developer ID Application: Your Name (TEAMID)" Screener.app
   ```
3. **Packaging:** Create a DMG (Disk Image) containing the signed `.app` bundle. Tools like `create-dmg` can automate this.
4. **Notarization:** To prevent Apple's Gatekeeper from blocking the app as "untrusted" on other users' machines, submit the DMG to Apple for notarization using `xcrun notarytool`.
5. **Publish:** Create a GitHub Release and attach the notarized `.dmg` file.
