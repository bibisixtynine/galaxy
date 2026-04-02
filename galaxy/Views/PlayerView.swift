//
//  PlayerView.swift
//  galaxy
//

import SwiftUI

// MARK: - Player View
struct PlayerView: View {
    let player: Player
    let gameTime: Double
    
    var body: some View {
        ZStack {
            // Engine glow
            Ellipse()
                .fill(RetroColors.neonBlue)
                .frame(width: 20 + 5 * sin(gameTime * 20), height: 30 + 10 * sin(gameTime * 15))
                .blur(radius: 10)
                .offset(y: 25)
            
            // Ship glow
            PixelShape(pixels: PlayerSprite.pixels)
                .fill(RetroColors.neonGreen)
                .frame(width: GameConstants.playerSize + 10, height: GameConstants.playerSize + 10)
                .blur(radius: 10)
                .opacity(0.6)
            
            // Main ship
            PixelShape(pixels: PlayerSprite.pixels)
                .fill(
                    LinearGradient(
                        colors: [RetroColors.neonGreen, RetroColors.neonBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: GameConstants.playerSize, height: GameConstants.playerSize)
            
            // Highlight
            PixelShape(pixels: PlayerSprite.pixels)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: GameConstants.playerSize, height: GameConstants.playerSize)
        }
        .opacity(player.isInvincible ? (sin(gameTime * 20) > 0 ? 1 : 0.3) : 1)
        .position(player.position)
    }
}
