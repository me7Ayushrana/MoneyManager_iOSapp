//
//  MintAIChatView.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Interactive MintAI Assistant Chat View supporting natural language financial Q&A and advice.
//

import SwiftUI

struct MintAIChatView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @StateObject private var viewModel = MintAIChatViewModel()
    
    let quickPrompts = [
        "How much did I spend this month?",
        "What is my top spending category?",
        "Give me 3 tips to save money based on my data",
        "Can I afford a 5,000 INR purchase?"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Toolbar
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.text_primary_color)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [Color.main_color, Color.main_color.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MintAI Financial Coach ✨")
                                    .modifier(InterFont(.bold, size: 16))
                                    .foregroundColor(Color.text_primary_color)
                                Text(GeminiAIService.shared.isKeyConfigured ? "Powered by Gemini 1.5 Flash" : "Tap to Setup API Key")
                                    .modifier(InterFont(.medium, size: 11))
                                    .foregroundColor(GeminiAIService.shared.isKeyConfigured ? Color.main_color : Color.red)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { viewModel.showKeySetup = true }) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.main_color)
                                .frame(width: 34, height: 34)
                                .background(Color.main_color.opacity(0.12))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Quick Prompts Horizontal Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickPrompts, id: \.self) { prompt in
                                Button(action: {
                                    viewModel.sendQuickQuery(prompt, moc: managedObjectContext, exchangeService: exchangeService)
                                }) {
                                    Text(prompt)
                                        .modifier(InterFont(.medium, size: 12))
                                        .foregroundColor(Color.text_primary_color)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.secondary_color)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.main_color.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    
                    Divider().background(Color.text_secondary_color.opacity(0.2))
                    
                    // Chat Messages Scroll
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                ForEach(viewModel.messages) { msg in
                                    ChatMessageBubble(message: msg)
                                        .id(msg.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color.main_color))
                                            Text("MintAI is analyzing your transactions...")
                                                .modifier(InterFont(.medium, size: 12))
                                                .foregroundColor(Color.text_secondary_color)
                                        }
                                        .padding(12)
                                        .background(Color.secondary_color)
                                        .cornerRadius(12)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastId = viewModel.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Bottom Input Bar
                    VStack(spacing: 0) {
                        Divider().background(Color.text_secondary_color.opacity(0.2))
                        HStack(spacing: 10) {
                            TextField("Ask MintAI about your money...", text: $viewModel.userInput)
                                .modifier(InterFont(.regular, size: 14))
                                .foregroundColor(Color.text_primary_color)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.secondary_color)
                                .cornerRadius(20)
                            
                            Button(action: {
                                viewModel.sendMessage(moc: managedObjectContext, exchangeService: exchangeService)
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(viewModel.userInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color.main_color)
                                    .cornerRadius(22)
                            }
                            .disabled(viewModel.userInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                        }
                        .padding(12)
                        .background(Color.primary_color)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $viewModel.showKeySetup) {
            GeminiKeySetupSheet()
        }
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text.replacingOccurrences(of: "**", with: ""))
                    .modifier(InterFont(.regular, size: 14))
                    .foregroundColor(message.isUser ? .white : Color.text_primary_color)
                    .lineSpacing(3)
                
                Text(DateFormatter.localizedString(from: message.date, dateStyle: .none, timeStyle: .short))
                    .modifier(InterFont(.regular, size: 10))
                    .foregroundColor(message.isUser ? .white.opacity(0.7) : Color.text_secondary_color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.isUser ? Color.main_color : Color.secondary_color)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal, 16)
    }
}
