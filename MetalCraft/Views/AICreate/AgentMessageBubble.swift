//
//  AgentMessageBubble.swift
//  MetalCraft
//
//  SwiftUI conversational bubble rendering user prompts, Gemini Creative Director reasoning,
//  Parallel research context, and embedded EditPlan cards.
//

import SwiftUI

struct AgentMessageBubble: View {
    let message: AgentMessage
    let onApplyPlan: ((EditPlan) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 40)
            } else {
                // Role Avatar
                ZStack {
                    Circle()
                        .fill(avatarBackground)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: avatarIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(avatarForeground)
                }
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Header (for agent/system)
                if message.role != .user {
                    HStack(spacing: 6) {
                        Text(senderTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        
                        Text(formattedTime(message.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // Content bubble
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Parallel Research Grounding Card
                if let research = message.researchContext, !research.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parallel Creative Research")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.indigo)
                            Text(research)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                // Embedded EditPlan Card
                if let plan = message.editPlan {
                    EditPlanPreviewView(plan: plan, onApply: onApplyPlan)
                        .padding(.top, 4)
                }
            }
            
            if message.role != .user {
                Spacer(minLength: 20)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var senderTitle: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Gemini Creative Director"
        case .system: return "System"
        case .researcher: return "Parallel Research"
        case .observer: return "Grafana Observability"
        }
    }
    
    private var avatarIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "wand.and.sparkles"
        case .system: return "exclamationmark.triangle.fill"
        case .researcher: return "book.pages"
        case .observer: return "chart.xyaxis.line"
        }
    }
    
    private var avatarBackground: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .purple.opacity(0.2)
        case .system: return .red.opacity(0.2)
        case .researcher: return .indigo.opacity(0.2)
        case .observer: return .orange.opacity(0.2)
        }
    }
    
    private var avatarForeground: Color {
        switch message.role {
        case .user: return .white
        case .assistant: return .purple
        case .system: return .red
        case .researcher: return .indigo
        case .observer: return .orange
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.role == .user {
                Color.accentColor
            } else if message.role == .system {
                Color.red.opacity(0.12)
            } else {
                Color(uiColor: .secondarySystemBackground)
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
