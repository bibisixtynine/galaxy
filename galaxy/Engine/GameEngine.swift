//
//  GameEngine.swift
//  galaxy
//

import SwiftUI

// MARK: - Game Engine
@Observable
class GameEngine {
    var gameState: GameState = .menu
    var player: Player
    var invaders: [Invader] = []
    var playerBullets: [Bullet] = []
    var invaderBullets: [Bullet] = []
    var particles: [Particle] = []
    var screenShake = ScreenShake()
    var flashEffect = FlashEffect()
    var score: Int = 0
    var highScore: Int = 0
    var wave: Int = 1
    var combo: Int = 0
    var comboTimer: Double = 0
    var invaderDirection: CGFloat = 1
    var invaderMoveTimer: Double = 0
    var lastInvaderShot: Double = 0
    var gameTime: Double = 0
    var stars: [Particle] = []
    var lastDiveAttack: Double = 0
    var diveAttackCooldown: Double = 8.0
    var dyingTimer: Double = 0          // Countdown during dying state
    var dyingPhase: Int = 0             // Tracks which wave of the explosion we're in
    var showGameOverPanel: Bool = false  // Show game over UI after explosion finishes
    
    // Cached filtered arrays for performance
    var aliveInvaders: [Invader] { invaders.filter { $0.isAlive } }
    var shockwaveParticles: [Particle] { particles.filter { $0.type == .shockwave } }
    var frontParticles: [Particle] { particles.filter { $0.type != .shockwave } }
    
    // Fixed reference resolution
    let screenWidth: CGFloat = GameConstants.referenceWidth
    let screenHeight: CGFloat = GameConstants.referenceHeight
    
    init() {
        self.player = Player(position: CGPoint(x: GameConstants.referenceWidth / 2, y: GameConstants.referenceHeight - 80))
        generateStars()
    }
    
    func generateStars() {
        stars = (0..<100).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                velocity: CGPoint(x: 0, y: CGFloat.random(in: 0.2...1.5)),
                color: [RetroColors.retroWhite, RetroColors.neonBlue, RetroColors.neonPurple].randomElement()!,
                size: CGFloat.random(in: 1...3),
                lifetime: 100,
                maxLifetime: 100,
                rotation: 0,
                rotationSpeed: 0,
                type: .star,
                alpha: Double.random(in: 0.3...1.0)
            )
        }
    }
    
    func startGame() {
        gameState = .playing
        score = 0
        wave = 1
        combo = 0
        dyingTimer = 0
        dyingPhase = 0
        showGameOverPanel = false
        player = Player(position: CGPoint(x: screenWidth / 2, y: screenHeight - 80))
        playerBullets = []
        invaderBullets = []
        particles = []
        spawnInvaders()
        flashEffect.trigger(color: RetroColors.neonGreen)
        SoundEngine.shared.playMenuSelect()
        SoundEngine.shared.startMusic()
    }
    
    func spawnInvaders() {
        invaders = []
        let startX = (screenWidth - CGFloat(GameConstants.invaderCols) * (GameConstants.invaderSize + GameConstants.invaderSpacing)) / 2 + GameConstants.invaderSize / 2
        let startY: CGFloat = 80
        
        for row in 0..<GameConstants.invaderRows {
            for col in 0..<GameConstants.invaderCols {
                let x = startX + CGFloat(col) * (GameConstants.invaderSize + GameConstants.invaderSpacing)
                let y = startY + CGFloat(row) * (GameConstants.invaderSize + GameConstants.invaderSpacing)
                let type = row < 1 ? 2 : (row < 3 ? 1 : 0)
                var invader = Invader(position: CGPoint(x: x, y: y), type: type)
                invader.gridPosition = CGPoint(x: x, y: y)
                invaders.append(invader)
            }
        }
        invaderDirection = 1
    }
    
    func update(deltaTime: Double) {
        gameTime += deltaTime
        
        // Always update visual effects (even during game over)
        screenShake.update()
        flashEffect.update()
        updateParticles(deltaTime: deltaTime)
        
        // Update stars
        for i in stars.indices {
            stars[i].position.y += stars[i].velocity.y
            if stars[i].position.y > screenHeight {
                stars[i].position.y = 0
                stars[i].position.x = CGFloat.random(in: 0...screenWidth)
            }
            stars[i].alpha = 0.3 + 0.7 * (0.5 + 0.5 * sin(gameTime * 3 + Double(i)))
        }
        
        // Handle dying state: game keeps running but player is gone
        if gameState == .dying {
            dyingTimer += deltaTime
            
            // Phased explosion waves over time
            if dyingPhase == 0 && dyingTimer >= 0.5 {
                dyingPhase = 1
                createIntergalacticExplosion(at: player.position, phase: 1)
            }
            if dyingPhase == 1 && dyingTimer >= 1.3 {
                dyingPhase = 2
                createIntergalacticExplosion(at: player.position, phase: 2)
            }
            if dyingPhase == 2 && dyingTimer >= 2.5 {
                dyingPhase = 3
                createIntergalacticExplosion(at: player.position, phase: 3)
            }
            if dyingPhase == 3 && dyingTimer >= 3.8 {
                dyingPhase = 4
                flashEffect.trigger(color: RetroColors.neonPink)
                screenShake.trigger(intensity: 20)
            }
            
            // Continuous fire particles streaming from the wreck
            if dyingTimer < 3.2 {
                // Spawn rate ramps up then down
                let rate: Int
                if dyingTimer < 0.5 { rate = 3 }
                else if dyingTimer < 1.3 { rate = 5 }
                else if dyingTimer < 2.5 { rate = 8 }
                else { rate = 3 }
                
                let spread = CGFloat(min(dyingTimer * 40, 120))
                spawnFireParticles(at: player.position, type: .spark, count: rate,
                                   speedRange: 2...16, lifetimeRange: 0.3...1.2, spread: spread)
                
                // Smooth continuous shake
                let shakeAmount: CGFloat = dyingTimer < 1.3 ? 10 : (dyingTimer < 2.5 ? 18 : 5)
                screenShake.trigger(intensity: shakeAmount)
                
                // Subtle warm flash pulses (not rainbow seizure)
                let flashPulse = 0.06 + 0.06 * sin(gameTime * 8)
                if flashEffect.alpha < flashPulse {
                    flashEffect.alpha = flashPulse
                    flashEffect.color = [RetroColors.neonOrange, RetroColors.neonYellow, RetroColors.neonPink][Int(gameTime * 3) % 3]
                }
            }
            
            // After the explosion finishes, show the game over panel
            if dyingTimer >= 4.5 && !showGameOverPanel {
                showGameOverPanel = true
                gameState = .gameOver
                SoundEngine.shared.playGameOver()
            }
            
            // Invaders keep moving and shooting during dying
            invaderMoveTimer += deltaTime
            let moveInterval = max(0.1, 0.8 - Double(wave) * 0.05 - Double(55 - invaders.filter { $0.isAlive }.count) * 0.01)
            if invaderMoveTimer >= moveInterval {
                invaderMoveTimer = 0
                moveInvaders()
            }
            for i in invaders.indices {
                if Int(gameTime * 4) % 2 == 0 {
                    invaders[i].animationFrame = (invaders[i].animationFrame + 1) % 2
                }
                if invaders[i].diveAttack.isDiving {
                    updateDiveAttack(index: i, deltaTime: deltaTime)
                }
            }
            lastInvaderShot += deltaTime
            let shootInterval = max(0.3, 1.5 - Double(wave) * 0.1)
            if lastInvaderShot >= shootInterval {
                lastInvaderShot = 0
                invaderShoot()
            }
            updateBullets()
            return
        }
        
        // Stop game logic if not playing
        guard gameState == .playing else { return }
        
        // Update combo timer
        if comboTimer > 0 {
            comboTimer -= deltaTime
            if comboTimer <= 0 {
                combo = 0
            }
        }
        
        // Update invaders
        invaderMoveTimer += deltaTime
        let moveInterval = max(0.1, 0.8 - Double(wave) * 0.05 - Double(55 - invaders.filter { $0.isAlive }.count) * 0.01)
        
        if invaderMoveTimer >= moveInterval {
            invaderMoveTimer = 0
            moveInvaders()
        }
        
        // Animate invaders and update dive attacks
        for i in invaders.indices {
            if Int(gameTime * 4) % 2 == 0 {
                invaders[i].animationFrame = (invaders[i].animationFrame + 1) % 2
            }
            if invaders[i].hitFlash > 0 {
                invaders[i].hitFlash -= deltaTime * 5
            }
            
            // Update diving invaders
            if invaders[i].diveAttack.isDiving {
                updateDiveAttack(index: i, deltaTime: deltaTime)
            }
        }
        
        // Trigger dive attacks (less frequent)
        lastDiveAttack += deltaTime
        let diveInterval = max(5.0, diveAttackCooldown - Double(wave) * 0.2)
        if lastDiveAttack >= diveInterval {
            lastDiveAttack = 0
            triggerDiveAttack()
        }
        
        // Update music intensity based on game state
        let aliveCount = Double(invaders.filter { $0.isAlive }.count)
        let totalCount = Double(GameConstants.invaderRows * GameConstants.invaderCols)
        let intensity = 0.3 + 0.7 * (1.0 - aliveCount / totalCount)
        SoundEngine.shared.setMusicIntensity(intensity)
        
        // Invader shooting
        lastInvaderShot += deltaTime
        let shootInterval = max(0.3, 1.5 - Double(wave) * 0.1)
        if lastInvaderShot >= shootInterval {
            lastInvaderShot = 0
            invaderShoot()
        }
        
        // Update bullets
        updateBullets()
        
        // Note: particles and effects already updated at start of function
        
        // Update player invincibility
        if player.isInvincible {
            player.invincibilityTimer -= deltaTime
            if player.invincibilityTimer <= 0 {
                player.isInvincible = false
            }
        }
        
        // Check collisions
        checkCollisions()
        
        // Check win condition
        if invaders.filter({ $0.isAlive }).isEmpty {
            nextWave()
        }
        
        // Check lose condition
        if player.lives <= 0 {
            gameOver()
        }
    }
    
    func triggerDiveAttack() {
        // Select 2-4 invaders for a group dive attack
        let availableInvaders = invaders.indices.filter { 
            invaders[$0].isAlive && !invaders[$0].diveAttack.isDiving 
        }
        guard availableInvaders.count >= 2 else { return }
        
        let groupSize = min(availableInvaders.count, Int.random(in: 2...4))
        let selectedIndices = availableInvaders.shuffled().prefix(groupSize)
        
        SoundEngine.shared.playDiveSound()
        
        for (offset, index) in selectedIndices.enumerated() {
            // Stagger the dive starts slightly
            let delay = Double(offset) * 0.15
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.invaders.indices.contains(index) else { return }
                
                self.invaders[index].diveAttack.isDiving = true
                self.invaders[index].diveAttack.startPosition = self.invaders[index].position
                self.invaders[index].diveAttack.progress = 0
                self.invaders[index].diveAttack.phase = 0
                self.invaders[index].diveAttack.spinSpeed = Double.random(in: 8...15) * (Bool.random() ? 1 : -1)
                self.invaders[index].diveAttack.targetPosition = CGPoint(
                    x: self.player.position.x + CGFloat.random(in: -100...100),
                    y: self.screenHeight - 150
                )
            }
        }
    }
    
    func updateDiveAttack(index: Int, deltaTime: Double) {
        // Very slow dive speed
        let speed = 0.35 + Double(wave) * 0.02
        invaders[index].diveAttack.progress += deltaTime * speed
        invaders[index].diveAttack.angle += invaders[index].diveAttack.spinSpeed * deltaTime
        
        let progress = invaders[index].diveAttack.progress
        let start = invaders[index].diveAttack.startPosition
        let target = invaders[index].diveAttack.targetPosition
        
        // Continuous fluid motion - all in one progress from 0 to 1
        let t = min(1.0, progress)
        
        // Shoot once at the bottom of the dive
        if t > 0.35 && t < 0.4 {
            let bullet = Bullet(
                position: invaders[index].position,
                velocity: CGPoint(x: CGFloat.random(in: -1...1), y: GameConstants.invaderBulletSpeed),
                isPlayerBullet: false,
                color: RetroColors.neonOrange
            )
            if !invaderBullets.contains(where: { 
                abs($0.position.x - bullet.position.x) < 50 && abs($0.position.y - bullet.position.y) < 50 
            }) {
                invaderBullets.append(bullet)
            }
        }
        
        // Fluid continuous path: down, swoop, up - all in one smooth motion
        let swoopDirection: CGFloat = invaders[index].diveAttack.spinSpeed > 0 ? 1 : -1
        
        if t < 0.4 {
            // Phase 1: Dive down (0 to 0.4)
            let phaseT = t / 0.4
            let curveX = sin(phaseT * .pi) * 100 * swoopDirection
            invaders[index].position.x = start.x + (target.x - start.x) * CGFloat(phaseT) + CGFloat(curveX)
            invaders[index].position.y = start.y + (target.y - start.y) * CGFloat(phaseT)
        } else if t < 0.6 {
            // Phase 2: Swoop across bottom (0.4 to 0.6)
            let phaseT = (t - 0.4) / 0.2
            let swoopDistance: CGFloat = 120
            invaders[index].position.x = target.x + swoopDirection * swoopDistance * CGFloat(phaseT)
            invaders[index].position.y = target.y + CGFloat(sin(phaseT * .pi)) * 20
        } else {
            // Phase 3: Return up to CURRENT grid position (0.6 to 1.0)
            let phaseT = (t - 0.6) / 0.4
            let swoopEndX = target.x + swoopDirection * 120
            let arcHeight = CGFloat(sin(phaseT * .pi)) * 60
            // Read gridPosition directly each frame to get updated position
            let currentGridPos = invaders[index].gridPosition
            invaders[index].position.x = swoopEndX + (currentGridPos.x - swoopEndX) * CGFloat(phaseT)
            invaders[index].position.y = target.y + (currentGridPos.y - target.y) * CGFloat(phaseT) - arcHeight
        }
        
        if t >= 1.0 {
            invaders[index].diveAttack.isDiving = false
            invaders[index].diveAttack.phase = 0
            invaders[index].diveAttack.angle = 0
            // Snap to current grid position when dive ends
            invaders[index].position = invaders[index].gridPosition
        }
        
        // Spawn trail particles while diving
        if invaders[index].diveAttack.phase < 2 && Int(gameTime * 20) % 2 == 0 {
            spawnParticles(at: invaders[index].position, type: .trail, count: 1, color: RetroColors.neonOrange)
        }
    }
    
    func moveInvaders() {
        var shouldDropAndReverse = false
        
        for invader in invaders where invader.isAlive && !invader.diveAttack.isDiving {
            let nextX = invader.position.x + invaderDirection * GameConstants.invaderMoveSpeed
            if nextX < GameConstants.invaderSize || nextX > screenWidth - GameConstants.invaderSize {
                shouldDropAndReverse = true
                break
            }
        }
        
        if shouldDropAndReverse {
            invaderDirection *= -1
            for i in invaders.indices {
                // Always update grid position (even for diving invaders)
                invaders[i].gridPosition.y += GameConstants.invaderDropAmount
                
                // Only move position if not diving
                if !invaders[i].diveAttack.isDiving {
                    invaders[i].position.y += GameConstants.invaderDropAmount
                }
                
                // Check if invaders reached player
                if invaders[i].isAlive && !invaders[i].diveAttack.isDiving && invaders[i].position.y > screenHeight - 120 {
                    gameOver()
                    return
                }
            }
        } else {
            for i in invaders.indices {
                // Always update grid position (even for diving invaders)
                invaders[i].gridPosition.x += invaderDirection * GameConstants.invaderMoveSpeed
                
                // Only move position if not diving
                if !invaders[i].diveAttack.isDiving {
                    invaders[i].position.x += invaderDirection * GameConstants.invaderMoveSpeed
                }
            }
        }
    }
    
    func invaderShoot() {
        let aliveInvaders = invaders.filter { $0.isAlive }
        guard !aliveInvaders.isEmpty else { return }
        
        // Bottom invaders have higher chance to shoot
        let bottomInvaders = Dictionary(grouping: aliveInvaders) { Int($0.position.x / 40) }
            .compactMapValues { $0.max(by: { $0.position.y < $1.position.y }) }
            .values
        
        if let shooter = bottomInvaders.randomElement() {
            let bullet = Bullet(
                position: shooter.position,
                velocity: CGPoint(x: CGFloat.random(in: -1...1), y: GameConstants.invaderBulletSpeed),
                isPlayerBullet: false,
                color: RetroColors.neonPink
            )
            invaderBullets.append(bullet)
            spawnParticles(at: shooter.position, type: .spark, count: 3, color: RetroColors.neonPink)
            SoundEngine.shared.playInvaderShoot()
        }
    }
    
    func playerShoot() {
        guard gameState == .playing else { return }
        
        let bullet = Bullet(
            position: CGPoint(x: player.position.x, y: player.position.y - 20),
            velocity: CGPoint(x: 0, y: -GameConstants.bulletSpeed),
            isPlayerBullet: true,
            color: RetroColors.neonGreen
        )
        playerBullets.append(bullet)
        spawnParticles(at: bullet.position, type: .spark, count: 5, color: RetroColors.neonGreen)
        screenShake.trigger(intensity: 2)
        SoundEngine.shared.playShoot()
    }
    
    func updateBullets() {
        // Update player bullets
        for i in playerBullets.indices {
            playerBullets[i].trail.insert(playerBullets[i].position, at: 0)
            if playerBullets[i].trail.count > 8 {
                playerBullets[i].trail.removeLast()
            }
            playerBullets[i].position.x += playerBullets[i].velocity.x
            playerBullets[i].position.y += playerBullets[i].velocity.y
        }
        playerBullets.removeAll { $0.position.y < -20 }
        
        // Update invader bullets
        for i in invaderBullets.indices {
            invaderBullets[i].trail.insert(invaderBullets[i].position, at: 0)
            if invaderBullets[i].trail.count > 6 {
                invaderBullets[i].trail.removeLast()
            }
            invaderBullets[i].position.x += invaderBullets[i].velocity.x
            invaderBullets[i].position.y += invaderBullets[i].velocity.y
        }
        invaderBullets.removeAll { $0.position.y > screenHeight + 20 }
    }
    
    func updateParticles(deltaTime: Double) {
        for i in particles.indices.reversed() {
            particles[i].lifetime -= deltaTime
            particles[i].rotation += particles[i].rotationSpeed
            
            switch particles[i].type {
            case .shockwave:
                particles[i].size += 8
                particles[i].alpha = particles[i].progress * 0.6
                
            case .shipFragment:
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                particles[i].velocity.y += 0.12
                particles[i].velocity.x *= 0.998
                let p = particles[i].progress
                particles[i].alpha = p > 0.2 ? 1.0 : p / 0.2
                // Flicker near end of life
                if p < 0.15 {
                    particles[i].alpha *= sin(gameTime * 20 + Double(i) * 7) > 0 ? 1.0 : 0.3
                }
                
            default:
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                particles[i].velocity.y += 0.2
                particles[i].alpha = particles[i].progress
            }
        }
        particles.removeAll { $0.lifetime <= 0 }
    }
    
    func checkCollisions() {
        // Player bullets vs invaders
        for bulletIndex in playerBullets.indices.reversed() {
            let bullet = playerBullets[bulletIndex]
            
            for invaderIndex in invaders.indices {
                guard invaders[invaderIndex].isAlive else { continue }
                let invader = invaders[invaderIndex]
                
                let dx = bullet.position.x - invader.position.x
                let dy = bullet.position.y - invader.position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < GameConstants.invaderSize / 2 {
                    // Hit!
                    invaders[invaderIndex].isAlive = false
                    playerBullets.remove(at: bulletIndex)
                    
                    // Score with combo
                    combo += 1
                    comboTimer = 2.0
                    let points = (invader.type + 1) * 10 * combo
                    score += points
                    if score > highScore {
                        highScore = score
                    }
                    
                    // Epic explosion!
                    createExplosion(at: invader.position, intensity: invader.type + 1)
                    
                    break
                }
            }
        }
        
        // Invader bullets vs player
        if !player.isInvincible {
            for bulletIndex in invaderBullets.indices.reversed() {
                let bullet = invaderBullets[bulletIndex]
                
                let dx = bullet.position.x - player.position.x
                let dy = bullet.position.y - player.position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < GameConstants.playerSize / 2 {
                    // Player hit!
                    invaderBullets.remove(at: bulletIndex)
                    playerHit()
                    break
                }
            }
        }
    }
    
    func playerHit() {
        player.lives -= 1
        player.isInvincible = true
        player.invincibilityTimer = 2.0
        
        createExplosion(at: player.position, intensity: 3)
        screenShake.trigger(intensity: 20)
        flashEffect.trigger(color: RetroColors.neonPink)
        SoundEngine.shared.playPlayerHit()
        
        if player.lives <= 0 {
            gameOver()
        }
    }
    
    func createExplosion(at position: CGPoint, intensity: Int) {
        // Main explosion particles
        spawnParticles(at: position, type: .explosion, count: 15 * intensity, color: RetroColors.neonOrange)
        spawnParticles(at: position, type: .spark, count: 10 * intensity, color: RetroColors.neonYellow)
        spawnParticles(at: position, type: .debris, count: 8 * intensity, color: RetroColors.retroWhite)
        
        // Shockwave
        particles.append(Particle(
            position: position,
            velocity: .zero,
            color: RetroColors.neonYellow,
            size: 10,
            lifetime: 0.3,
            maxLifetime: 0.3,
            rotation: 0,
            rotationSpeed: 0,
            type: .shockwave
        ))
        
        screenShake.trigger(intensity: CGFloat(intensity * 5))
        if intensity >= 2 {
            flashEffect.trigger(color: RetroColors.neonOrange)
        }
        SoundEngine.shared.playExplosion(intensity: intensity)
    }
    
    func spawnParticles(at position: CGPoint, type: ParticleType, count: Int, color: Color) {
        for _ in 0..<count {
            let angle = Double.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 2...8)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed - (type == .explosion ? 3 : 0)
            )
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                color: color,
                size: type == .explosion ? CGFloat.random(in: 3...8) : CGFloat.random(in: 2...5),
                lifetime: Double.random(in: 0.3...0.8),
                maxLifetime: 0.8,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -10...10),
                type: type
            )
            particles.append(particle)
        }
    }
    
    // Fire-colored particle burst helper
    func spawnFireParticles(at position: CGPoint, type: ParticleType, count: Int, speedRange: ClosedRange<CGFloat>, lifetimeRange: ClosedRange<Double>, spread: CGFloat = 0) {
        let fireColors: [Color] = [
            RetroColors.neonOrange, RetroColors.neonYellow, RetroColors.neonPink,
            Color(red: 1.0, green: 0.3, blue: 0.1), // deep orange
            Color(red: 1.0, green: 0.7, blue: 0.2), // amber
            .white
        ]
        for _ in 0..<count {
            let angle = Double.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: speedRange)
            let origin = CGPoint(
                x: position.x + CGFloat.random(in: -spread...spread),
                y: position.y + CGFloat.random(in: -spread...spread)
            )
            particles.append(Particle(
                position: origin,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed - (type == .explosion ? 2 : 0)
                ),
                color: fireColors.randomElement()!,
                size: type == .spark ? CGFloat.random(in: 4...8) : CGFloat.random(in: 6...12),
                lifetime: Double.random(in: lifetimeRange),
                maxLifetime: lifetimeRange.upperBound,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -10...10),
                type: type
            ))
        }
    }
    
    func createIntergalacticExplosion(at position: CGPoint, phase: Int) {
        switch phase {
        case 0:
            // === PHASE 0: Ship shatters — fragments fly out + initial fire burst ===
            
            // Ship fragments — real PixelShape pieces tumbling away
            let fragmentAngles: [Double] = [
                -.pi * 0.5,   // top spike goes up
                -.pi * 0.85,  // left wing goes upper-left
                -.pi * 0.15,  // right wing goes upper-right
                .pi,          // center body goes left
                .pi * 0.65,   // left engine goes down-left
                .pi * 0.35    // right engine goes down-right
            ]
            for (i, _) in PlayerSprite.fragments.enumerated() {
                let angle = fragmentAngles[i] + Double.random(in: -0.2...0.2)
                let speed = CGFloat.random(in: 4.5...8.0)
                particles.append(Particle(
                    position: position,
                    velocity: CGPoint(x: CGFloat(cos(angle)) * speed, y: CGFloat(sin(angle)) * speed),
                    color: [RetroColors.neonGreen, RetroColors.neonBlue].randomElement()!,
                    size: CGFloat.random(in: 18...28),
                    lifetime: 4.0,
                    maxLifetime: 4.0,
                    rotation: Double(i) * 60,
                    rotationSpeed: Double.random(in: -5...5),
                    type: .shipFragment
                ))
            }
            
            // Initial fire burst — same style as invader explosions but bigger
            spawnFireParticles(at: position, type: .explosion, count: 40, speedRange: 6...20, lifetimeRange: 0.4...1.2)
            spawnFireParticles(at: position, type: .spark, count: 30, speedRange: 8...24, lifetimeRange: 0.3...1.0)
            spawnParticles(at: position, type: .debris, count: 15, color: RetroColors.retroWhite)
            
            // Shockwave
            particles.append(Particle(
                position: position, velocity: .zero,
                color: RetroColors.neonGreen,
                size: 10, lifetime: 0.5, maxLifetime: 0.5,
                rotation: 0, rotationSpeed: 0, type: .shockwave
            ))
            
            screenShake.trigger(intensity: 35)
            flashEffect.trigger(color: .white)
            
        case 1:
            // === PHASE 1: Secondary explosion (0.5s) — fire erupts from wreckage ===
            
            spawnFireParticles(at: position, type: .explosion, count: 60, speedRange: 4...24, lifetimeRange: 0.5...1.5, spread: 40)
            spawnFireParticles(at: position, type: .spark, count: 50, speedRange: 10...32, lifetimeRange: 0.3...1.2, spread: 30)
            spawnParticles(at: position, type: .debris, count: 20, color: RetroColors.neonOrange)
            
            // Shockwave
            particles.append(Particle(
                position: position, velocity: .zero,
                color: RetroColors.neonOrange,
                size: 10, lifetime: 0.6, maxLifetime: 0.6,
                rotation: 0, rotationSpeed: 0, type: .shockwave
            ))
            
            screenShake.trigger(intensity: 45)
            flashEffect.trigger(color: RetroColors.neonOrange)
            
            // Kill nearby invaders
            for i in invaders.indices where invaders[i].isAlive {
                let dx = invaders[i].position.x - position.x
                let dy = invaders[i].position.y - position.y
                if sqrt(dx*dx + dy*dy) < 180 {
                    invaders[i].isAlive = false
                    createExplosion(at: invaders[i].position, intensity: 2)
                }
            }
            
        case 2:
            // === PHASE 2: THE BIG ONE (1.3s) — massive fireball ===
            
            // Massive explosion particle burst
            spawnFireParticles(at: position, type: .explosion, count: 100, speedRange: 6...36, lifetimeRange: 0.8...2.0, spread: 60)
            spawnFireParticles(at: position, type: .spark, count: 80, speedRange: 12...44, lifetimeRange: 0.4...1.5, spread: 40)
            spawnParticles(at: position, type: .debris, count: 30, color: RetroColors.neonYellow)
            spawnParticles(at: position, type: .debris, count: 20, color: RetroColors.retroWhite)
            
            // Multiple shockwaves
            for i in 0..<3 {
                particles.append(Particle(
                    position: position, velocity: .zero,
                    color: [.white, RetroColors.neonYellow, RetroColors.neonPink][i],
                    size: 10, lifetime: 0.6 + Double(i) * 0.1, maxLifetime: 0.9,
                    rotation: 0, rotationSpeed: 0, type: .shockwave
                ))
            }
            
            screenShake.trigger(intensity: 60)
            flashEffect.trigger(color: .white)
            
            // Kill invaders in wide radius
            for i in invaders.indices where invaders[i].isAlive {
                let dx = invaders[i].position.x - position.x
                let dy = invaders[i].position.y - position.y
                if sqrt(dx*dx + dy*dy) < 350 {
                    invaders[i].isAlive = false
                    createExplosion(at: invaders[i].position, intensity: 2)
                }
            }
            
        case 3:
            // === PHASE 3: Aftermath — embers rain down (2.5s) ===
            
            // Gentle falling embers/sparks from the blast area
            spawnFireParticles(at: position, type: .spark, count: 60, speedRange: 1...8, lifetimeRange: 1.5...3.5, spread: 240)
            spawnFireParticles(at: position, type: .explosion, count: 30, speedRange: 1...6, lifetimeRange: 1.0...3.0, spread: 200)
            
            // Debris floating
            for _ in 0..<25 {
                let angle = Double.random(in: 0...(.pi * 2))
                let speed = CGFloat.random(in: 1...6)
                particles.append(Particle(
                    position: CGPoint(
                        x: position.x + CGFloat.random(in: -200...200),
                        y: position.y + CGFloat.random(in: -120...60)
                    ),
                    velocity: CGPoint(x: CGFloat(cos(angle)) * speed, y: CGFloat(sin(angle)) * speed),
                    color: [RetroColors.neonGreen, RetroColors.neonBlue, RetroColors.retroWhite].randomElement()!,
                    size: CGFloat.random(in: 2...6),
                    lifetime: Double.random(in: 2.0...4.0),
                    maxLifetime: 4.0,
                    rotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: -8...8),
                    type: .debris
                ))
            }
            
            screenShake.trigger(intensity: 8)
            
        default:
            break
        }
    }
    
    func nextWave() {
        wave += 1
        spawnInvaders()
        flashEffect.trigger(color: RetroColors.neonBlue)
        screenShake.trigger(intensity: 10)
        SoundEngine.shared.playWaveComplete()
        
        // Bonus particles
        for _ in 0..<50 {
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: 0...screenHeight / 2)
            spawnParticles(at: CGPoint(x: x, y: y), type: .spark, count: 1, color: RetroColors.neonBlue)
        }
    }
    
    func gameOver() {
        guard gameState == .playing else { return }
        gameState = .dying
        dyingTimer = 0
        dyingPhase = 0
        showGameOverPanel = false
        
        // Stop music, start the epic explosion
        SoundEngine.shared.stopMusic()
        SoundEngine.shared.playIntergalacticExplosion()
        
        // Launch phase 0 immediately: initial flash + ship breakup
        createIntergalacticExplosion(at: player.position, phase: 0)
    }
    
    func movePlayer(to x: CGFloat) {
        player.position.x = min(max(x, GameConstants.playerSize / 2), screenWidth - GameConstants.playerSize / 2)
    }
}
