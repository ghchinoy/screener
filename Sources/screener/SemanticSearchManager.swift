import Foundation
import NaturalLanguage
import Accelerate

class SemanticSearchManager {
    static let shared = SemanticSearchManager()
    
    // NLEmbedding for English sentences
    private let textEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    
    private init() {}
    
    /// Converts a string into a normalized Float vector using Apple's On-Device NaturalLanguage framework.
    func getLocalTextEmbedding(for text: String) -> [Float]? {
        guard let embedding = textEmbedding else { return nil }
        guard let doubleVector = embedding.vector(for: text) else { return nil }
        
        // Convert [Double] to [Float]
        let floatVector = doubleVector.map { Float($0) }
        
        // Normalize the vector (L2 norm) so cosine similarity is just a dot product
        return normalize(floatVector)
    }
    
    /// Computes the cosine similarity between two normalized vectors using the Accelerate framework.
    /// Returns a value between -1.0 and 1.0.
    func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count, a.count > 0 else { return 0.0 }
        
        var dotProduct: Float = 0.0
        let length = vDSP_Length(a.count)
        
        // Since both vectors should already be normalized, the dot product IS the cosine similarity.
        vDSP_dotpr(a, 1, b, 1, &dotProduct, length)
        
        return dotProduct
    }
    
    func normalize(_ vector: [Float]) -> [Float] {
        var norm: Float = 0.0
        let length = vDSP_Length(vector.count)
        
        // Calculate sum of squares
        vDSP_svesq(vector, 1, &norm, length)
        
        if norm == 0 { return vector }
        let magnitude = sqrt(norm)
        
        // Divide each element by the magnitude
        var normalized = [Float](repeating: 0.0, count: vector.count)
        var divisor = magnitude
        vDSP_vsdiv(vector, 1, &divisor, &normalized, 1, length)
        
        return normalized
    }
}
