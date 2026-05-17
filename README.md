# Video Screener

Video Screener is a macOS native SwiftUI application built for developers, editors, and filmmakers to rapidly browse, analyze, and organize video files. It leverages SwiftData and Google Cloud Vertex AI to provide intelligent, offline-capable, and AI-driven video metadata extraction.

<img width="1977" height="1097" alt="Image" src="https://github.com/user-attachments/assets/2ef56291-62f9-46de-b3c3-4bef6ab10143" />

## Features

- **macOS HIG Layout**: Utilizes a fully compliant `HSplitView` and Inspector pane for resizable, distraction-free analysis.
- **SwiftData Persistence**: Video metadata, technical information, and custom comments are preserved locally on your machine automatically as you browse.
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

1. Ensure you have Apple's Swift toolchain and `gcloud` CLI installed.
2. Authenticate locally with GCP: `gcloud auth application-default login`
3. Run the application:
   ```bash
   make run
   ```

## Development & Schema Changes

If you modify the `VideoMetadata.swift` model during development, the application will crash on launch due to a lack of automatic schema migrations. You can safely clear the local database by running:
```bash
make reset-db
```
