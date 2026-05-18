# Hybrid Semantic Search Architecture

Video Screener implements a cutting-edge **Hybrid Semantic Search** architecture. Rather than relying on traditional keyword matching or a single cloud provider, it fuses Apple's on-device Machine Learning frameworks with Google Cloud's multimodal foundation models.

This allows the application to remain lightning-fast and offline-capable for basic queries, while seamlessly scaling to deep visual semantic matching when required—all without needing a dedicated heavy vector database like Pinecone or Milvus.

![Architecture Diagram](architecture.png)

## 1. The Pre-Processing Pipeline (Gemini Analysis)

Before generating the `Local Text Vector`, the application must extract high-quality, structured text metadata from the video. It does this by passing the video to the standard Vertex AI `generateContent` endpoint using the `gemini-3.1-flash-lite` model.

The application uses a highly specific prompt to instruct the multimodal model to act as a structured data extractor:
> "Analyze this video and output a JSON object containing exactly these keys: summary, tags, transcript, colorMood, motionType, contentSafety."

Because Gemini natively understands both the visual frames and the audio track, it can simultaneously:
*   **Transcript:** Listen to the audio and transcribe speech.
*   **Motion Type:** Observe temporal changes between frames to classify camera movement (e.g., "Drone flyover", "Static tripod", "Handheld pan").
*   **Color Mood:** Analyze the dominant color palettes and lighting (e.g., "Warm golden hour", "High contrast neon").
*   **Summary & Tags:** Synthesize the overall narrative into concise text.

This rich, structured JSON is saved to the `VideoMetadata` SwiftData model, providing the foundation for the local text embedding.

## 2. The Dual-Vector Index

For every video processed, Video Screener stores two distinct, normalized vectors directly inside the local `SwiftData` SQLite store as binary `Data` blobs:

### A. Local Text Vector (Apple `NLEmbedding`)
*   **Source:** Concatenated text from Gemini (Summary, Tags, Transcript, Mood, Motion) + User Comments.
*   **Engine:** Apple's NaturalLanguage framework (`NLEmbedding.sentenceEmbedding`).
*   **Dimensionality:** 512 dimensions.
*   **Characteristics:** Generated instantaneously, 100% on-device, zero cost, completely private.

### B. Cloud Visual Vector (Vertex AI `gemini-embedding-2`)
*   **Source:** The raw binary `.mp4` / `.mov` video file.
*   **Engine:** Google Cloud Vertex AI (`gemini-embedding-2` or `gemini-embedding-2-preview`).
*   **Dimensionality:** 1,408 dimensions.
*   **Characteristics:** Requires an API call. Projects the actual visual and audio content into a multimodal semantic space, allowing users to search for visuals that were never explicitly described in the text summary.

## 2. The Search Execution

The application handles search execution using **Apple's Accelerate Framework (`vDSP`)**. 
Because vectors are normalized at generation time, calculating cosine similarity is simplified to a highly-optimized dot product calculation:
`vDSP_dotpr(a, 1, b, 1, &dotProduct, length)`

Using hardware-accelerated matrix math on Apple Silicon (M-Series chips), the app can compare a search query against tens of thousands of local vectors in single-digit milliseconds, directly in the SwiftUI run loop.

### Search Modes

1. **Local Text Search (Default):** 
   As the user types, the query is converted to an `NLEmbedding` locally. `vDSP` instantly scores and filters the list against the local summaries and comments. It feels like magic, but consumes zero network bandwidth.
2. **Cloud Visual Search:**
   When toggled, the text query is sent to Vertex AI's `embedContent` endpoint to retrieve a 1,408-dimensional text vector. This vector is then compared against the raw `cloudVisualVector` of every video locally using `vDSP`. This mode allows finding videos based on abstract visual concepts ("drone flying over water at sunset") that cross modalities.
