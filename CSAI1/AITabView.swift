//
//  AITabView.swift
//  CSAI1
//
//  Final version with API integration for ChatGPT.
//    - Faster "Hide" animation for the prompt bar
//    - Smaller floating "Show Prompts" button, placed lower
//    - iOS 17 toolbar fix
//    - Timestamps on long-press for user messages
//    - Large, relevant crypto prompts
//    - All original conversation callbacks
//    - Integrated ChatGPT API call replacing mock responses
//

import SwiftUI

// MARK: - API Key for Testing (Do NOT use this approach in production)
private let openAIAPIKey = "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"

// MARK: - AITabView
struct AITabView: View {
    // All stored conversations
    @State private var conversations: [Conversation] = []
    // Which conversation is currently active
    @State private var activeConversationID: UUID? = nil
    
    // Controls whether the history sheet is shown
    @State private var showHistory = false
    
    // The user's chat input
    @State private var chatText: String = ""
    // Whether the AI is "thinking"
    @State private var isThinking: Bool = false
    
    // Whether to show or hide the prompt bar
    @State private var showPromptBar: Bool = true
    
    // A larger, more relevant list of prompts for a crypto/portfolio AI
    private let masterPrompts: [String] = [
        "What's the current price of BTC?",
        "Compare Ethereum and Bitcoin",
        "Show me a 24h price chart for SOL",
        "How is my portfolio performing?",
        "What's the best time to buy crypto?",
        "What is staking and how does it work?",
        "Are there any new DeFi projects I should watch?",
        "Give me the top gainers and losers today",
        "Explain yield farming",
        "Should I buy or sell right now?",
        "What are the top 10 coins by market cap?",
        "What's the difference between a limit and market order?",
        "Show me a price chart for RLC",
        "What is a stablecoin?",
        "Any new NFT trends?",
        "Compare LTC with DOGE",
        "Is my portfolio well diversified?",
        "How to minimize fees when trading?",
        "What's the best exchange for altcoins?"
    ]
    
    // Currently displayed quick replies
    @State private var quickReplies: [String] = []
    
    // Computed: returns the messages for the active conversation
    private var currentMessages: [ChatMessage] {
        guard let activeID = activeConversationID,
              let index = conversations.firstIndex(where: { $0.id == activeID }) else {
            return []
        }
        return conversations[index].messages
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main chat
                chatBodyView
                
                // If prompt bar is hidden, show a floating button to reveal it
                if !showPromptBar {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showPromptBar = true
                            } label: {
                                // Lightbulb icon for "Prompts", smaller and offset
                                Image(systemName: "lightbulb")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(10)
                                    .background(Color.yellow.opacity(0.8))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                            // Move up from bottom so it doesn't collide with Send
                            .padding(.trailing, 20)
                            .padding(.bottom, 80)
                        }
                    }
                    // Only fade out quickly
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                // 1) Custom principal item
                ToolbarItem(placement: .principal) {
                    Text(activeConversationTitle())
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                // 2) Left icon for conversation history
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory.toggle()
                    } label: {
                        Image(systemName: "text.bubble")
                            .imageScale(.large)
                    }
                    .foregroundColor(.white)
                    .sheet(isPresented: $showHistory) {
                        // ConversationHistoryView with callbacks
                        ConversationHistoryView(
                            conversations: conversations,
                            onSelectConversation: { convo in
                                activeConversationID = convo.id
                                showHistory = false
                                saveConversations()
                            },
                            onNewChat: {
                                let newConvo = Conversation(title: "Untitled Chat")
                                conversations.append(newConvo)
                                activeConversationID = newConvo.id
                                showHistory = false
                                saveConversations()
                            },
                            onDeleteConversation: { convo in
                                if let idx = conversations.firstIndex(where: { $0.id == convo.id }) {
                                    conversations.remove(at: idx)
                                    if convo.id == activeConversationID {
                                        activeConversationID = conversations.first?.id
                                    }
                                    saveConversations()
                                }
                            },
                            onRenameConversation: { convo, newTitle in
                                if let idx = conversations.firstIndex(where: { $0.id == convo.id }) {
                                    conversations[idx].title = newTitle.isEmpty ? "Untitled Chat" : newTitle
                                    saveConversations()
                                }
                            },
                            onTogglePin: { convo in
                                if let idx = conversations.firstIndex(where: { $0.id == convo.id }) {
                                    conversations[idx].pinned.toggle()
                                    saveConversations()
                                }
                            }
                        )
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    }
                }
            })
            .onAppear {
                loadConversations()
                if activeConversationID == nil, let first = conversations.first {
                    activeConversationID = first.id
                }
                randomizePrompts()
            }
        }
    }
}

// MARK: - Subviews & Helpers
extension AITabView {
    /// The main chat content
    private var chatBodyView: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(currentMessages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                            if isThinking {
                                thinkingIndicator()
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: currentMessages.count) {
                        withAnimation {
                            if let lastID = currentMessages.last?.id {
                                scrollProxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // If prompt bar is shown, show it
                if showPromptBar {
                    quickReplyBar()
                }
                
                // Input bar
                inputBar()
            }
        }
    }
    
    private func activeConversationTitle() -> String {
        guard let activeID = activeConversationID,
              let convo = conversations.first(where: { $0.id == activeID }) else {
            return "AI Chat"
        }
        return convo.title
    }
    
    private func thinkingIndicator() -> some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("CryptoSage is thinking...")
                .foregroundColor(.white)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    /// Quick replies row with shuffle arrow and a hide icon
    private func quickReplyBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Show each quick reply as a button
                ForEach(quickReplies, id: \.self) { reply in
                    Button(reply) {
                        handleQuickReply(reply)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.yellow.opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                }
                
                // Shuffle arrow icon
                Button {
                    randomizePrompts()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.yellow.opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                }
                
                // Hide icon
                Button {
                    withAnimation(.easeOut(duration: 0.1)) {
                        showPromptBar = false
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.yellow.opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .simultaneousGesture(DragGesture(minimumDistance: 10))
        }
        .background(Color.black.opacity(0.3))
        .transition(.opacity.animation(.easeOut(duration: 0.1)))
    }
    
    private func inputBar() -> some View {
        HStack {
            TextField("Ask your AI...", text: $chatText)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            
            Button(action: sendMessage) {
                Text("Send")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.yellow.opacity(0.8))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
    }
    
    private func sendMessage() {
        guard let activeID = activeConversationID,
              let index = conversations.firstIndex(where: { $0.id == activeID }) else {
            let newConvo = Conversation(title: "Untitled Chat")
            conversations.append(newConvo)
            activeConversationID = newConvo.id
            saveConversations()
            return
        }
        
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var convo = conversations[index]
        let userMsg = ChatMessage(sender: "user", text: trimmed)
        convo.messages.append(userMsg)
        
        // Update title if first message in "Untitled Chat"
        if convo.title == "Untitled Chat" && convo.messages.count == 1 {
            convo.title = String(trimmed.prefix(20)) + (trimmed.count > 20 ? "..." : "")
        }
        
        conversations[index] = convo
        chatText = ""
        saveConversations()
        
        // Instead of simulating a response, call the OpenAI API
        isThinking = true
        callOpenAI(for: index)
    }
    
    /// Calls OpenAI's ChatGPT API with the current conversation and appends the response.
    private func callOpenAI(for index: Int) {
        let convo = conversations[index]
        // Map your messages: use "user" for user messages and "assistant" for AI messages.
        let apiMessages = convo.messages.map { msg -> [String: String] in
            let role = (msg.sender == "user") ? "user" : "assistant"
            return ["role": role, "content": msg.text]
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": apiMessages
        ]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            DispatchQueue.main.async {
                self.isThinking = false
                var updatedConvo = self.conversations[index]
                let errorMsg = ChatMessage(sender: "ai", text: "Failed to encode request: \(error.localizedDescription)", isError: true)
                updatedConvo.messages.append(errorMsg)
                self.conversations[index] = updatedConvo
                self.saveConversations()
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isThinking = false
            }
            if let error = error {
                DispatchQueue.main.async {
                    var updatedConvo = self.conversations[index]
                    let errorMsg = ChatMessage(sender: "ai", text: "Request error: \(error.localizedDescription)", isError: true)
                    updatedConvo.messages.append(errorMsg)
                    self.conversations[index] = updatedConvo
                    self.saveConversations()
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    var updatedConvo = self.conversations[index]
                    let errorMsg = ChatMessage(sender: "ai", text: "No data received from API.", isError: true)
                    updatedConvo.messages.append(errorMsg)
                    self.conversations[index] = updatedConvo
                    self.saveConversations()
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
                        var updatedConvo = self.conversations[index]
                        let aiMsg = ChatMessage(sender: "ai", text: trimmedContent)
                        updatedConvo.messages.append(aiMsg)
                        self.conversations[index] = updatedConvo
                        self.saveConversations()
                    }
                } else {
                    DispatchQueue.main.async {
                        var updatedConvo = self.conversations[index]
                        let errorMsg = ChatMessage(sender: "ai", text: "Unexpected response format from API.", isError: true)
                        updatedConvo.messages.append(errorMsg)
                        self.conversations[index] = updatedConvo
                        self.saveConversations()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    var updatedConvo = self.conversations[index]
                    let errorMsg = ChatMessage(sender: "ai", text: "Decoding error: \(error.localizedDescription)", isError: true)
                    updatedConvo.messages.append(errorMsg)
                    self.conversations[index] = updatedConvo
                    self.saveConversations()
                }
            }
        }.resume()
    }
    
    private func handleQuickReply(_ reply: String) {
        chatText = reply
        sendMessage()
    }
    
    private func randomizePrompts() {
        let shuffled = masterPrompts.shuffled()
        quickReplies = Array(shuffled.prefix(4))
    }
    
    private func clearActiveConversation() {
        guard let activeID = activeConversationID,
              let index = conversations.firstIndex(where: { $0.id == activeID }) else { return }
        var convo = conversations[index]
        convo.messages.removeAll()
        conversations[index] = convo
        saveConversations()
    }
}

// MARK: - Persistence
extension AITabView {
    private func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            UserDefaults.standard.set(data, forKey: "csai_conversations")
        } catch {
            print("Failed to encode conversations: \(error)")
        }
    }
    
    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: "csai_conversations") else { return }
        do {
            conversations = try JSONDecoder().decode([Conversation].self, from: data)
        } catch {
            print("Failed to decode conversations: \(error)")
        }
    }
}

// MARK: - ChatBubble
struct ChatBubble: View {
    let message: ChatMessage
    
    @State private var showTimestamp: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            if message.sender == "ai" {
                aiView
                Spacer()
            } else {
                Spacer()
                userView
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // AI messages: white text, no bubble, always show timestamp
    private var aiView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text(formattedTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // User messages: yellow bubble, black text, timestamp on long press
    private var userView: some View {
        let bubbleColor: Color = message.isError
            ? Color.red.opacity(0.8)
            : Color.yellow.opacity(0.8)
        
        let textColor: Color = message.isError ? .white : .black
        
        return VStack(alignment: .trailing, spacing: 4) {
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(textColor)
            
            if showTimestamp {
                Text("Sent at \(formattedTime(message.timestamp))")
                    .font(.caption2)
                    .foregroundColor(textColor.opacity(0.7))
            }
        }
        .padding(12)
        .background(bubbleColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onLongPressGesture {
            showTimestamp.toggle()
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
