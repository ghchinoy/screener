# Video Screener

Video Screener is a macOS native SwiftUI application built for developers, editors, and filmmakers to rapidly browse, analyze, and organize video files. It leverages SwiftData and Google Cloud Vertex AI to provide intelligent, offline-capable, and AI-driven video metadata extraction.

<img width="1977" height="1097" alt="Image" src="https://github.com/user-attachments/assets/2ef56291-62f9-46de-b3c3-4bef6ab10143" />

## Features

- **macOS HIG Layout**: Utilizes a fully compliant `HSplitView` and Inspector pane for resizable, distraction-free analysis. Features a custom 3D Gemini-styled macOS app icon.
- **SwiftData Persistence**: Video metadata, technical information, and custom comments are preserved locally on your machine automatically as you browse.
- **Content Credentials (C2PA) Mock Integration**: Seamlessly detects and parses C2PA signatures and assertions (e.g., `c2pa.training-mining: notAllowed`) out of video manifests. Features a dedicated expandable modal detailing cryptographically signed provenance (Currently using a Mock implementation due to `c2pa-ios` macOS binary constraints).
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

If you modify the `VideoMetadata.swift` model during development, the application will crash on launch (`NSCocoaErrorDomain 134110`) due to a lack of automatic schema migrations in SwiftData. You can safely clear the local database by running:
```bash
make reset-db
```
