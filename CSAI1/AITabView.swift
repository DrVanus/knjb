import SwiftUI

struct AITabView: View {
    @StateObject private var viewModel = AIChatViewModel()
    @State private var chatText: String = ""
    @State private var showPromptBar: Bool = true
    @State private var quickReplies: [String] = [
        "What's the current price of BTC?",
        "Compare Ethereum and Bitcoin",
        "Explain yield farming",
        "How is my portfolio performing?"
    ]
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Black background
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.currentMessages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }
                                if viewModel.isThinking {
                                    thinkingIndicator()
                                }
                            }
                            .padding(.vertical)
                        }
                        .onChange(of: viewModel.currentMessages.count) { _ in
                            withAnimation {
                                if let lastID = viewModel.currentMessages.last?.id {
                                    scrollProxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                    }
                    if showPromptBar {
                        quickReplyBar()
                    }
                    inputBar()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("AI Chat")
        }
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
    
    private func quickReplyBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickReplies, id: \.self) { reply in
                    Button(action: {
                        chatText = reply
                        sendMessage()
                    }) {
                        Text(reply)
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
                }
                Button(action: {
                    withAnimation(.easeOut(duration: 0.1)) {
                        showPromptBar = false
                    }
                }) {
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
        }
        .background(Color.black.opacity(0.3))
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
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.sendMessage(trimmed)
        chatText = ""
    }
}

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
    
    private var userView: some View {
        let bubbleColor: Color = message.isError ? Color.red.opacity(0.8) : Color.yellow.opacity(0.8)
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
