//
//  HUDView.swift
//  galaxy
//

import SwiftUI

// MARK: - HUD View
struct HUDView: View {
    let score: Int
    let highScore: Int
    let lives: Int
    let wave: Int
    let combo: Int
    let comboTimer: Double
    let gameTime: Double
    
    var body: some View {
        VStack {
            HStack {
                // Score
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroColors.neonGreen.opacity(0.7))
                    Text("\(score)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(RetroColors.neonGreen)
                        .shadow(color: RetroColors.neonGreen, radius: 10)
                }
                
                Spacer()
                
                // Wave
                VStack(spacing: 2) {
                    Text("WAVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroColors.neonPurple.opacity(0.7))
                    Text("\(wave)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(RetroColors.neonPurple)
                        .shadow(color: RetroColors.neonPurple, radius: 10)
                }
                
                Spacer()
                
                // High Score
                VStack(alignment: .trailing, spacing: 2) {
                    Text("HIGH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(RetroColors.neonYellow.opacity(0.7))
                    Text("\(highScore)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(RetroColors.neonYellow)
                        .shadow(color: RetroColors.neonYellow, radius: 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            HStack {
                // Lives
                HStack(spacing: 5) {
                    ForEach(0..<lives, id: \.self) { i in
                        PixelShape(pixels: PlayerSprite.pixels)
                            .fill(RetroColors.neonGreen)
                            .frame(width: 20, height: 20)
                            .shadow(color: RetroColors.neonGreen, radius: 5)
                    }
                }
                
                Spacer()
                
                // Combo
                if combo > 1 {
                    Text("COMBO x\(combo)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(RetroColors.neonOrange)
                        .shadow(color: RetroColors.neonOrange, radius: 10)
                        .scaleEffect(1 + 0.1 * sin(gameTime * 10))
                        .opacity(comboTimer > 0.5 ? 1 : comboTimer * 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 5)
            
            Spacer()
        }
    }
}
