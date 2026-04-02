//
//  InvaderView.swift
//  galaxy
//

import SwiftUI

// MARK: - Invader View
struct InvaderView: View {
    let invader: Invader
    let gameTime: Double
    
    var body: some View {
        let sprite = InvaderSprites.sprite(type: invader.type, frame: invader.animationFrame)
        let baseColor = invader.diveAttack.isDiving ? RetroColors.neonOrange : InvaderSprites.color(type: invader.type)
        
        ZStack {
            // Dive trail glow
            if invader.diveAttack.isDiving {
                Circle()
                    .fill(RetroColors.neonOrange)
                    .frame(width: GameConstants.invaderSize * 1.5, height: GameConstants.invaderSize * 1.5)
                    .blur(radius: 15)
                    .opacity(0.6)
            }
            
            // Glow effect
            PixelShape(pixels: sprite)
                .fill(baseColor)
                .frame(width: GameConstants.invaderSize + 8, height: GameConstants.invaderSize + 8)
                .blur(radius: invader.diveAttack.isDiving ? 12 : 8)
                .opacity(invader.diveAttack.isDiving ? 0.8 : 0.5 + 0.2 * sin(gameTime * 5))
            
            // Main sprite
            PixelShape(pixels: sprite)
                .fill(invader.hitFlash > 0 ? .white : baseColor)
                .frame(width: GameConstants.invaderSize, height: GameConstants.invaderSize)
            
            // Highlight
            PixelShape(pixels: sprite)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: GameConstants.invaderSize, height: GameConstants.invaderSize)
        }
        .rotationEffect(.degrees(invader.diveAttack.angle))
        .scaleEffect(invader.diveAttack.isDiving ? 1.2 : 1.0)
        .position(invader.position)
    }
}
