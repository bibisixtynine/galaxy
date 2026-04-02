//
//  GameModels.swift
//  galaxy
//

import SwiftUI

// MARK: - Game Constants
struct GameConstants {
    // Reference resolution (game runs at this size internally)
    // MacBook 16:10 aspect ratio
    static let referenceWidth: CGFloat = 1280
    static let referenceHeight: CGFloat = 800
    
    static let invaderRows = 5
    static let invaderCols = 11
    static let invaderSpacing: CGFloat = 16
    static let invaderSize: CGFloat = 52
    static let playerSize: CGFloat = 64
    static let bulletSize: CGFloat = 14
    static let bulletSpeed: CGFloat = 16
    static let invaderBulletSpeed: CGFloat = 8
    static let invaderMoveSpeed: CGFloat = 28
    static let invaderDropAmount: CGFloat = 32
}

// MARK: - Game Colors (Retro Palette)
struct RetroColors {
    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let neonPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    static let neonBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let neonYellow = Color(red: 1.0, green: 0.9, blue: 0.2)
    static let neonOrange = Color(red: 1.0, green: 0.5, blue: 0.1)
    static let neonPurple = Color(red: 0.7, green: 0.2, blue: 1.0)
    static let retroWhite = Color(red: 0.95, green: 0.95, blue: 0.9)
    static let darkBg = Color(red: 0.02, green: 0.02, blue: 0.08)
}

// MARK: - Particle Types
enum ParticleType {
    case explosion
    case spark
    case trail
    case debris
    case shockwave
    case star
    case shipFragment  // Piece of the player ship breaking apart
}

// MARK: - Particle Model
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var size: CGFloat
    var lifetime: Double
    var maxLifetime: Double
    var rotation: Double
    var rotationSpeed: Double
    var type: ParticleType
    var alpha: Double = 1.0
    
    var progress: Double {
        lifetime / maxLifetime
    }
}

// MARK: - Dive Attack State
struct DiveAttack {
    var isDiving: Bool = false
    var startPosition: CGPoint = .zero
    var targetPosition: CGPoint = .zero
    var progress: Double = 0
    var phase: Int = 0  // 0: dive down, 1: swoop, 2: return or exit
    var angle: Double = 0
    var spinSpeed: Double = 0
}

// MARK: - Invader Model
struct Invader: Identifiable {
    let id = UUID()
    var position: CGPoint
    var type: Int // 0, 1, 2 for different shapes
    var isAlive: Bool = true
    var animationFrame: Int = 0
    var hitFlash: Double = 0
    var gridPosition: CGPoint = .zero  // Original grid position
    var diveAttack: DiveAttack = DiveAttack()
}

// MARK: - Bullet Model
struct Bullet: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var isPlayerBullet: Bool
    var color: Color
    var trail: [CGPoint] = []
}

// MARK: - Player Model
struct Player {
    var position: CGPoint
    var lives: Int = 3
    var isInvincible: Bool = false
    var invincibilityTimer: Double = 0
}

// MARK: - Screen Shake
struct ScreenShake {
    var intensity: CGFloat = 0
    var offset: CGSize = .zero
    
    mutating func trigger(intensity: CGFloat) {
        self.intensity = intensity
    }
    
    mutating func update() {
        if intensity > 0.1 {
            offset = CGSize(
                width: CGFloat.random(in: -intensity...intensity),
                height: CGFloat.random(in: -intensity...intensity)
            )
            intensity *= 0.85
        } else {
            intensity = 0
            offset = .zero
        }
    }
}

// MARK: - Flash Effect
struct FlashEffect {
    var alpha: Double = 0
    var color: Color = .white
    
    mutating func trigger(color: Color = .white) {
        self.alpha = 0.8
        self.color = color
    }
    
    mutating func update() {
        if alpha > 0.01 {
            alpha *= 0.8
        } else {
            alpha = 0
        }
    }
}

// MARK: - Game State
enum GameState {
    case menu
    case playing
    case dying        // Explosion plays, game keeps running
    case gameOver
    case victory
}
