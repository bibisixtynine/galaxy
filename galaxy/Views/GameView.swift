//
//  GameView.swift
//  galaxy
//

import SwiftUI

// MARK: - Scanline Overlay (Optimized with Canvas)
struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 3) {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.08)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Grid Overlay
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let spacing: CGFloat = 40
                
                for x in stride(from: 0, to: geo.size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                
                for y in stride(from: 0, to: geo.size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(RetroColors.neonBlue, lineWidth: 1)
        }
    }
}

// MARK: - Game View
struct GameView: View {
    @State private var engine = GameEngine()
    @State private var lastUpdate = Date()
    @State private var timer: Timer?
    
    private func scale(for size: CGSize) -> CGFloat {
        min(size.width / GameConstants.referenceWidth, 
            size.height / GameConstants.referenceHeight)
    }
    
    var body: some View {
        GeometryReader { geo in
            let currentScale = scale(for: geo.size)
            
            ZStack {
                // Background
                RetroColors.darkBg
                    .ignoresSafeArea()
                
                // Scaled game content
                ZStack {
                    // Stars
                    ForEach(engine.stars) { star in
                        ParticleView(particle: star)
                    }
                    
                    // Grid lines (subtle)
                    GridOverlay()
                        .opacity(0.05)
                    
                    // Game content
                    ZStack {
                        // Particles (behind) - shockwaves
                        ForEach(engine.shockwaveParticles) { particle in
                            ParticleView(particle: particle)
                        }
                        
                        // Invaders
                        ForEach(engine.aliveInvaders) { invader in
                            InvaderView(invader: invader, gameTime: engine.gameTime)
                        }
                        
                        // Bullets
                        ForEach(engine.playerBullets) { bullet in
                            BulletView(bullet: bullet, gameTime: engine.gameTime)
                        }
                        ForEach(engine.invaderBullets) { bullet in
                            BulletView(bullet: bullet, gameTime: engine.gameTime)
                        }
                        
                        // Player
                        if engine.gameState == .playing {
                            PlayerView(player: engine.player, gameTime: engine.gameTime)
                        }
                        
                        // Particles (front)
                        ForEach(engine.frontParticles) { particle in
                            ParticleView(particle: particle)
                        }
                    }
                    .offset(engine.screenShake.offset)
                    
                    // Flash effect
                    RetroColors.retroWhite
                        .opacity(engine.flashEffect.alpha)
                        .allowsHitTesting(false)
                    
                    // HUD
                    if engine.gameState == .playing || engine.gameState == .dying {
                        HUDView(
                            score: engine.score,
                            highScore: engine.highScore,
                            lives: engine.player.lives,
                            wave: engine.wave,
                            combo: engine.combo,
                            comboTimer: engine.comboTimer,
                            gameTime: engine.gameTime
                        )
                    }
                    
                    // Menu overlay
                    if engine.gameState == .menu {
                        MenuView(gameTime: engine.gameTime) {
                            engine.startGame()
                        }
                    }
                    
                    // Game over overlay (only after explosion finishes)
                    if engine.showGameOverPanel || engine.gameState == .victory {
                        Color.black.opacity(0.5)
                        
                        GameOverView(
                            score: engine.score,
                            highScore: engine.highScore,
                            wave: engine.wave,
                            isVictory: engine.gameState == .victory,
                            gameTime: engine.gameTime
                        ) {
                            engine.startGame()
                        }
                    }
                }
                .frame(width: GameConstants.referenceWidth, height: GameConstants.referenceHeight)
                .scaleEffect(currentScale, anchor: .center)
                .frame(width: geo.size.width, height: geo.size.height)
                
                // Scanlines (not scaled, covers full window)
                ScanlineOverlay()
                    .ignoresSafeArea()
                
                // Vignette (not scaled, covers full window)
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.6)],
                    center: .center,
                    startRadius: min(geo.size.width, geo.size.height) * 0.4,
                    endRadius: max(geo.size.width, geo.size.height) * 0.7
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    // Convert screen coordinates to game coordinates
                    let offsetX = (geo.size.width - GameConstants.referenceWidth * currentScale) / 2
                    let gameX = (location.x - offsetX) / currentScale
                    engine.movePlayer(to: gameX)
                case .ended:
                    break
                }
            }
            .onTapGesture {
                engine.playerShoot()
            }
            .onAppear {
                startGameLoop()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    func startGameLoop() {
        let newTimer = Timer(timeInterval: 1/60, repeats: true) { _ in
            let now = Date()
            let deltaTime = now.timeIntervalSince(lastUpdate)
            lastUpdate = now
            engine.update(deltaTime: min(deltaTime, 0.1))
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
}
