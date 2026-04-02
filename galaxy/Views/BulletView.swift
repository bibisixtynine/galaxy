//
//  BulletView.swift
//  galaxy
//

import SwiftUI

// MARK: - Bullet View
struct BulletView: View {
    let bullet: Bullet
    let gameTime: Double
    
    var body: some View {
        ZStack {
            // Trail
            ForEach(Array(bullet.trail.enumerated()), id: \.offset) { index, pos in
                Circle()
                    .fill(bullet.color)
                    .frame(width: GameConstants.bulletSize * (1 - CGFloat(index) * 0.1),
                           height: GameConstants.bulletSize * (1 - CGFloat(index) * 0.1))
                    .opacity(1 - Double(index) * 0.12)
                    .blur(radius: 2)
                    .position(pos)
            }
            
            // Glow
            Circle()
                .fill(bullet.color)
                .frame(width: GameConstants.bulletSize + 8, height: GameConstants.bulletSize + 8)
                .blur(radius: 6)
                .position(bullet.position)
            
            // Core
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: GameConstants.bulletSize - 2, height: GameConstants.bulletSize + 4)
                .position(bullet.position)
        }
    }
}
