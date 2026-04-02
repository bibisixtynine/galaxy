//
//  ParticleView.swift
//  galaxy
//

import SwiftUI

// MARK: - Particle View
struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        Group {
            switch particle.type {
            case .shockwave:
                Circle()
                    .stroke(particle.color, lineWidth: 2)
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: 1)
                    .opacity(particle.alpha)
                    .position(particle.position)
                
            case .explosion:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: 1)
                    .opacity(particle.alpha)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(particle.position)
                
            case .spark:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.alpha)
                    .position(particle.position)
                
            case .debris:
                Rectangle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.5)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(particle.alpha)
                    .position(particle.position)
                
            case .trail:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: 2)
                    .opacity(particle.alpha * 0.5)
                    .position(particle.position)
                
            case .star:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.alpha)
                    .position(particle.position)
                
            case .shipFragment:
                let fragmentIndex = abs(Int(particle.rotation * 100)) % PlayerSprite.fragments.count
                ZStack {
                    // Fire glow trailing behind the fragment
                    Circle()
                        .fill(RetroColors.neonOrange)
                        .frame(width: particle.size * 0.7, height: particle.size * 0.7)
                        .blur(radius: 6)
                        .opacity(particle.alpha * 0.5)
                        .offset(x: -particle.velocity.x * 0.8, y: -particle.velocity.y * 0.8)
                    
                    // Glow around the fragment
                    PixelShape(pixels: PlayerSprite.fragments[fragmentIndex])
                        .fill(particle.color)
                        .frame(width: particle.size + 4, height: (particle.size + 4) * 0.8)
                        .blur(radius: 4)
                        .opacity(particle.alpha * 0.4)
                    
                    // The pixel art fragment
                    PixelShape(pixels: PlayerSprite.fragments[fragmentIndex])
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 0.8)
                    
                    // Hot white highlight
                    PixelShape(pixels: PlayerSprite.fragments[fragmentIndex])
                        .fill(.white.opacity(0.4))
                        .frame(width: particle.size, height: particle.size * 0.8)
                        .mask(
                            LinearGradient(colors: [.white, .clear],
                                           startPoint: .top, endPoint: .center)
                        )
                }
                .rotationEffect(.degrees(particle.rotation))
                .opacity(particle.alpha)
                .position(particle.position)
            }
        }
    }
}
