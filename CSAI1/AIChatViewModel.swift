import Foundation
import SwiftUI

// MARK: - Data Models

struct ChatMessage: Identifiable, Codable {
    // Use a variable for id so it can be overwritten during decoding if needed.
    var id: UUID = UUID()
    let sender: String   // "user" or "ai"
    let text: String
    // We'll initialize the timestamp automatically.
    let timestamp: Date = Date()
    let isError: Bool
    
    init(sender: String, text: String, isError: Bool = false) {
        self.sender = sender
        self.text = text
        self.isError = isError
    }
}

struct Conversation: Identifiable, Codable {
    // Use a variable for id so decoding can set it.
    var id: UUID = UUID()
    var title: String
    var pinned: Bool = false
    var messages: [ChatMessage] = []
    
    init(title: String) {
        self.title = title
    }
}

// MARK: - ViewModel

class AIChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var activeConversationID: UUID? = nil
    @Published var isThinking: Bool = false

    // API key for testing – for production, store this securely!
    private let openAIAPIKey = "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"
    
    private let storageKey = "csai_conversations"
    
    init() {
        loadConversations()
        if activeConversationID == nil, let first = conversations.first {
            activeConversationID = first.id
        }
    }
    
    var currentMessages: [ChatMessage] {
        guard let activeID = activeConversationID,
              let index = conversations.firstIndex(where: { $0.id == activeID })
        else { return [] }
        return conversations[index].messages
    }
    
    /// Sends a user message to the active conversation and triggers an API call.
    func sendMessage(_ text: String) {
        guard let activeID = activeConversationID,
              let index = conversations.firstIndex(where: { $0.id == activeID })
        else {
            // If no active conversation exists, create one.
            let newConvo = Conversation(title: "Untitled Chat")
            conversations.append(newConvo)
            activeConversationID = newConvo.id
            saveConversations()
            return
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var convo = conversations[index]
        let userMsg = ChatMessage(sender: "user", text: trimmed)
        convo.messages.append(userMsg)
        
        // If this is the first message in an untitled chat, update the title.
        if convo.title == "Untitled Chat" && convo.messages.count == 1 {
            convo.title = String(trimmed.prefix(20)) + (trimmed.count > 20 ? "..." : "")
        }
        
        conversations[index] = convo
        saveConversations()
        
        isThinking = true
        callOpenAI(for: index)
    }
    
    /// Calls OpenAI's chat API using the entire conversation.
    private func callOpenAI(for index: Int) {
        let convo = conversations[index]
        // Map messages into the format expected by OpenAI.
        let apiMessages = convo.messages.map { msg -> [String: String] in
            let role = (msg.sender == "user") ? "user" : "assistant"
            return ["role": role, "content": msg.text]
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": apiMessages
        ]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            DispatchQueue.main.async {
                self.isThinking = false
                self.appendErrorMessage("Invalid API URL.", toConversationAt: index)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            DispatchQueue.main.async {
                self.isThinking = false
                self.appendErrorMessage("Failed to encode request: \(error.localizedDescription)", toConversationAt: index)
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isThinking = false }
            if let error = error {
                DispatchQueue.main.async {
                    self.appendErrorMessage("Request error: \(error.localizedDescription)", toConversationAt: index)
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.appendErrorMessage("No data received from API.", toConversationAt: index)
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let messageDict = firstChoice["message"] as? [String: Any],
                   let content = messageDict["content"] as? String {
                    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    DispatchQueue.main.async {
                        self.appendAIMessage(trimmedContent, toConversationAt: index)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.appendErrorMessage("Unexpected response format from API.", toConversationAt: index)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.appendErrorMessage("Decoding error: \(error.localizedDescription)", toConversationAt: index)
                }
            }
        }.resume()
    }
    
    private func appendAIMessage(_ text: String, toConversationAt index: Int) {
        var convo = conversations[index]
        let aiMsg = ChatMessage(sender: "ai", text: text)
        convo.messages.append(aiMsg)
        conversations[index] = convo
        saveConversations()
    }
    
    private func appendErrorMessage(_ text: String, toConversationAt index: Int) {
        var convo = conversations[index]
        let errorMsg = ChatMessage(sender: "ai", text: text, isError: true)
        convo.messages.append(errorMsg)
        conversations[index] = convo
        saveConversations()
    }
    
    // MARK: - Persistence
    
    func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode conversations: \(error)")
        }
    }
    
    func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            conversations = try JSONDecoder().decode([Conversation].self, from: data)
        } catch {
            print("Failed to decode conversations: \(error)")
        }
    }
}
