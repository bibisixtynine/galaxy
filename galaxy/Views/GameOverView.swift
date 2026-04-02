//
//  GameOverView.swift
//  galaxy
//

import SwiftUI

// MARK: - Game Over View
struct GameOverView: View {
    let score: Int
    let highScore: Int
    let wave: Int
    let isVictory: Bool
    let gameTime: Double
    let onRestart: () -> Void
    
    private var titleColor: Color {
        isVictory ? RetroColors.neonGreen : RetroColors.neonPink
    }
    
    private var titleText: String {
        isVictory ? "VICTORY!" : "GAME OVER"
    }
    
    private var isNewHighScore: Bool {
        score >= highScore && score > 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            titleView
            statsView
            if isNewHighScore {
                highScoreBadge
            }
            playAgainButton
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 30)
        .frame(width: 280)
        .background(panelBackground)
    }
    
    private var titleView: some View {
        Text(titleText)
            .font(.system(size: 36, weight: .black, design: .monospaced))
            .foregroundColor(titleColor)
            .shadow(color: titleColor, radius: 15)
            .scaleEffect(1 + 0.03 * sin(gameTime * 5))
    }
    
    private var statsView: some View {
        VStack(spacing: 12) {
            StatRow(label: "SCORE", value: "\(score)", color: RetroColors.neonYellow)
            StatRow(label: "WAVE", value: "\(wave)", color: RetroColors.neonPurple)
            StatRow(label: "BEST", value: "\(highScore)", color: RetroColors.neonBlue)
        }
        .padding(.vertical, 10)
    }
    
    private var highScoreBadge: some View {
        Text("NEW HIGH SCORE!")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(RetroColors.neonOrange)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(RetroColors.neonOrange, lineWidth: 1)
            )
            .opacity(0.7 + 0.3 * sin(gameTime * 8))
    }
    
    private var playAgainButton: some View {
        Button(action: onRestart) {
            Text("PLAY AGAIN")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(RetroColors.neonGreen)
                        .shadow(color: RetroColors.neonGreen.opacity(0.6), radius: 10)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
    }
    
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [RetroColors.neonPink, RetroColors.neonPurple, RetroColors.neonBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: RetroColors.neonPurple.opacity(0.3), radius: 30)
    }
}

// Helper view for stat rows
struct StatRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(RetroColors.retroWhite.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
