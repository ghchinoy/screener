import SwiftUI
import Foundation

@MainActor
class AppLogger: ObservableObject {
    static let shared = AppLogger()
    
    @Published var messages: [LogMessage] = []
    
    struct LogMessage: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let text: String
        let isError: Bool
    }
    
    private init() {}
    
    func log(_ text: String, isError: Bool = false) {
        let msg = LogMessage(text: text, isError: isError)
        messages.append(msg)
        print("\(isError ? "🔴 ERROR:" : "🟢 INFO:") \(text)")
    }
}
