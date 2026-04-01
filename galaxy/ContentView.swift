//
//  ContentView.swift
//  galaxy
//
//  Created by Jérôme Binachon on 01/04/2026.
//

import SwiftUI
import AVFoundation

// MARK: - Sound Engine
class SoundEngine {
    static let shared = SoundEngine()
    
    private var audioEngine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var currentNodeIndex = 0
    private let nodeCount = 8
    private var format: AVAudioFormat?
    private var isReady = false
    private var isMuted = false  // Block new sounds during game over
    
    // Music system
    private var musicNode: AVAudioPlayerNode?
    private var musicTimer: Timer?
    private var musicState = MusicState()
    
    private struct MusicState {
        var baseNote: Int = 0
        var pattern: Int = 0
        var beat: Int = 0
        var intensity: Double = 0.3
        var scale: [Int] = [0, 2, 3, 5, 7, 8, 10, 12] // Minor scale
        var chordProgression: [[Int]] = [[0, 3, 7], [5, 8, 12], [3, 7, 10], [7, 10, 14]]
        var currentChord: Int = 0
        var arpIndex: Int = 0
        var isSadMode: Bool = false
    }
    
    private init() {
        setupAudio()
    }
    
    private func setupAudio() {
        let engine = AVAudioEngine()
        
        // Use the mixer's output format to ensure compatibility
        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        
        // Ensure valid format
        guard mixerFormat.sampleRate > 0 && mixerFormat.channelCount > 0 else {
            return
        }
        
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: mixerFormat.sampleRate, channels: mixerFormat.channelCount) else {
            return
        }
        
        format = audioFormat
        
        for _ in 0..<nodeCount {
            let playerNode = AVAudioPlayerNode()
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
            playerNodes.append(playerNode)
        }
        
        // Music node
        let musicPlayerNode = AVAudioPlayerNode()
        engine.attach(musicPlayerNode)
        engine.connect(musicPlayerNode, to: engine.mainMixerNode, format: audioFormat)
        musicNode = musicPlayerNode
        
        do {
            try engine.start()
            audioEngine = engine
            isReady = true
        } catch {
            // Audio not available, game will run silently
        }
    }
    
    func startMusic() {
        guard isReady else { return }
        isMuted = false  // Re-enable sounds for new game
        stopMusic()
        musicState = MusicState()
        musicNode?.play()
        
        // Start music loop
        musicTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.playMusicBeat()
        }
        RunLoop.main.add(musicTimer!, forMode: .common)
    }
    
    func stopMusic() {
        musicTimer?.invalidate()
        musicTimer = nil
        musicNode?.stop()
        musicNode?.reset()  // Clear any scheduled buffers
    }
    
    func stopAllSounds() {
        isMuted = true  // Block any delayed sounds from playing
        stopMusic()
        // Stop and reset all player nodes to clear any pending buffers
        for node in playerNodes {
            node.stop()
            node.reset()
        }
    }
    
    func unmute() {
        isMuted = false
    }
    
    func setMusicIntensity(_ intensity: Double) {
        musicState.intensity = max(0.1, min(1.0, intensity))
    }
    
    func setMusicSadMode(_ sad: Bool) {
        musicState.isSadMode = sad
        if sad {
            musicState.intensity = 0.15  // Just lower intensity
        }
    }
    
    private func playMusicBeat() {
        guard isReady, let format = format else { return }
        
        let isSad = musicState.isSadMode
        let baseFreq = 55.0 // A1
        let beat = musicState.beat
        let chord = musicState.chordProgression[musicState.currentChord]
        let volume = isSad ? 0.5 : 1.0  // Just quieter when sad
        
        // Bass line (every 4 beats)
        if beat % 4 == 0 {
            let bassNote = chord[0] + (musicState.currentChord * 2) % 12
            let bassFreq = baseFreq * pow(2.0, Double(bassNote) / 12.0)
            playMusicTone(frequency: bassFreq, duration: 0.3, volume: 0.25 * volume, type: .triangle)
        }
        
        // Arpeggio
        if beat % 2 == 0 {
            let arpNote = chord[musicState.arpIndex % chord.count] + 12
            let arpFreq = baseFreq * 2 * pow(2.0, Double(arpNote) / 12.0)
            playMusicTone(frequency: arpFreq, duration: 0.12, volume: 0.15 * musicState.intensity * volume, type: .square)
            musicState.arpIndex += 1
        }
        
        // Lead melody (probabilistic, more frequent at high intensity)
        if Double.random(in: 0...1) < musicState.intensity * 0.3 {
            let melodyNote = musicState.scale.randomElement()! + 24 + (beat % 8 < 4 ? 0 : 2)
            let melodyFreq = baseFreq * pow(2.0, Double(melodyNote) / 12.0)
            playMusicTone(frequency: melodyFreq, duration: 0.1, volume: 0.12 * musicState.intensity * volume, type: .sine)
        }
        
        // Hi-hat style noise (on off-beats at high intensity, disabled when sad)
        if !isSad && musicState.intensity > 0.5 && beat % 2 == 1 {
            playMusicTone(frequency: 8000, duration: 0.03, volume: 0.05, type: .noise)
        }
        
        // Advance beat
        musicState.beat += 1
        if musicState.beat >= 16 {
            musicState.beat = 0
            musicState.currentChord = (musicState.currentChord + 1) % musicState.chordProgression.count
            
            // Occasionally change pattern
            if Int.random(in: 0..<4) == 0 {
                musicState.scale = [
                    [0, 2, 3, 5, 7, 8, 10, 12],  // Minor
                    [0, 2, 4, 5, 7, 9, 11, 12],  // Major
                    [0, 2, 3, 5, 7, 8, 11, 12],  // Harmonic minor
                    [0, 3, 5, 6, 7, 10, 12, 15]  // Blues
                ].randomElement()!
            }
        }
    }
    
    private func playMusicTone(frequency: Double, duration: Double, volume: Double, type: WaveType) {
        guard isReady, let format = format, let musicNode = musicNode else { return }
        
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let frameCount = Int(duration * sampleRate)
        
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else { return }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            var sample: Float
            
            switch type {
            case .square:
                let phase = time * frequency
                sample = (phase.truncatingRemainder(dividingBy: 1.0) < 0.5) ? 1.0 : -1.0
                sample *= 0.3
            case .noise:
                sample = Float.random(in: -0.3...0.3)
            case .triangle:
                let phase = (time * frequency).truncatingRemainder(dividingBy: 1.0)
                sample = Float(phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase))
                sample *= 0.4
            case .sine:
                sample = Float(sin(time * frequency * 2 * .pi) * 0.3)
            }
            
            // Envelope
            let attack = min(1.0, Double(frame) / (sampleRate * 0.01))
            let release = min(1.0, Double(frameCount - frame) / (sampleRate * 0.05))
            sample *= Float(attack * release * volume)
            
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
        
        musicNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
    
    func playDiveSound() {
        // Swooping sound for dive attack
        let startFreq = 600.0
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                let freq = startFreq - Double(i) * 80
                self.playTone(frequency: freq, duration: 0.06, type: .square, decay: true, volume: 0.2)
            }
        }
    }
    
    func playShoot() {
        playTone(frequency: 880, duration: 0.05, type: .square, decay: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            self.playTone(frequency: 440, duration: 0.05, type: .square, decay: true)
        }
    }
    
    func playExplosion(intensity: Int = 1) {
        let baseFreq = 150.0 - Double(intensity) * 30
        playTone(frequency: baseFreq, duration: 0.15 + Double(intensity) * 0.05, type: .noise, decay: true)
        playTone(frequency: baseFreq * 0.5, duration: 0.2, type: .noise, decay: true)
    }
    
    func playInvaderShoot() {
        playTone(frequency: 220, duration: 0.08, type: .square, decay: true)
    }
    
    func playPlayerHit() {
        playTone(frequency: 100, duration: 0.3, type: .noise, decay: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 80, duration: 0.2, type: .noise, decay: true)
        }
    }
    
    func playWaveComplete() {
        let notes: [Double] = [523.25, 659.25, 783.99, 1046.50]
        for (index, freq) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                self.playTone(frequency: freq, duration: 0.15, type: .square, decay: false)
            }
        }
    }
    
    func playGameOver() {
        // Music continues unchanged - just play game over sound
        let notes: [Double] = [392.00, 349.23, 329.63, 293.66]
        for (index, freq) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                self.playTone(frequency: freq, duration: 0.25, type: .square, decay: true)
            }
        }
    }
    
    func playMenuSelect() {
        playTone(frequency: 660, duration: 0.08, type: .square, decay: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.playTone(frequency: 880, duration: 0.1, type: .square, decay: false)
        }
    }
    
    private enum WaveType {
        case square, noise, triangle, sine
    }
    
    private func playTone(frequency: Double, duration: Double, type: WaveType, decay: Bool, volume: Double = 1.0) {
        guard isReady, !isMuted, let format = format else { return }
        
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let frameCount = Int(duration * sampleRate)
        
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            var sample: Float
            
            switch type {
            case .square:
                let phase = time * frequency
                sample = (phase.truncatingRemainder(dividingBy: 1.0) < 0.5) ? 0.3 : -0.3
            case .noise:
                sample = Float.random(in: -0.4...0.4)
                let lowFreqMod = sin(time * frequency * 2 * .pi)
                sample *= Float(0.5 + 0.5 * lowFreqMod)
            case .triangle:
                let phase = (time * frequency).truncatingRemainder(dividingBy: 1.0)
                sample = Float(phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase)) * 0.3
            case .sine:
                sample = Float(sin(time * frequency * 2 * .pi) * 0.3)
            }
            
            if decay {
                let envelope = Float(1.0 - Double(frame) / Double(frameCount))
                sample *= envelope * envelope
            }
            
            sample *= Float(volume)
            
            // Write to all channels (stereo compatibility)
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
        
        let node = playerNodes[currentNodeIndex]
        currentNodeIndex = (currentNodeIndex + 1) % nodeCount
        
        if node.isPlaying {
            node.stop()
        }
        
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
    }
}

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
    case gameOver
    case victory
}

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
        guard playerBullets.count < 3 else { return }
        
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
            particles[i].position.x += particles[i].velocity.x
            particles[i].position.y += particles[i].velocity.y
            particles[i].velocity.y += 0.2 // gravity
            particles[i].rotation += particles[i].rotationSpeed
            particles[i].alpha = particles[i].progress
            
            if particles[i].type == .shockwave {
                particles[i].size += 8
                particles[i].alpha = particles[i].progress * 0.6
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
        gameState = .gameOver
        screenShake.trigger(intensity: 30)
        flashEffect.trigger(color: RetroColors.neonPink)
        SoundEngine.shared.playGameOver()
    }
    
    func movePlayer(to x: CGFloat) {
        player.position.x = min(max(x, GameConstants.playerSize / 2), screenWidth - GameConstants.playerSize / 2)
    }
}

// MARK: - Pixel Art Shapes
struct PixelShape: Shape {
    let pixels: [[Int]]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pixelSize = rect.width / CGFloat(pixels[0].count)
        
        for (row, rowData) in pixels.enumerated() {
            for (col, pixel) in rowData.enumerated() {
                if pixel == 1 {
                    let x = CGFloat(col) * pixelSize
                    let y = CGFloat(row) * pixelSize
                    path.addRect(CGRect(x: x, y: y, width: pixelSize, height: pixelSize))
                }
            }
        }
        return path
    }
}

// MARK: - Invader Sprites
struct InvaderSprites {
    static let type0Frame0 = [
        [0,0,1,0,0,0,0,0,1,0,0],
        [0,0,0,1,0,0,0,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,0,0],
        [0,1,1,0,1,1,1,0,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,0,1,1,1,1,1,1,1,0,1],
        [1,0,1,0,0,0,0,0,1,0,1],
        [0,0,0,1,1,0,1,1,0,0,0]
    ]
    
    static let type0Frame1 = [
        [0,0,1,0,0,0,0,0,1,0,0],
        [1,0,0,1,0,0,0,1,0,0,1],
        [1,0,1,1,1,1,1,1,1,0,1],
        [1,1,1,0,1,1,1,0,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,0,0,0,0,0,1,0,0],
        [0,1,0,0,0,0,0,0,0,1,0]
    ]
    
    static let type1Frame0 = [
        [0,0,0,1,1,1,1,1,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,0,0,1,0,0,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [0,0,1,1,0,0,0,1,1,0,0],
        [0,1,1,0,1,1,1,0,1,1,0],
        [1,1,0,0,0,0,0,0,0,1,1]
    ]
    
    static let type1Frame1 = [
        [0,0,0,1,1,1,1,1,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,0,0,1,0,0,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [0,0,0,1,0,0,0,1,0,0,0],
        [0,0,1,0,1,1,1,0,1,0,0],
        [0,1,0,1,0,0,0,1,0,1,0]
    ]
    
    static let type2Frame0 = [
        [0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,1,1,1,1,0,0,0,0],
        [0,0,1,1,1,1,1,1,0,0,0],
        [0,1,1,0,1,1,0,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,0,0,1,0,0,0,0],
        [0,0,1,0,1,1,0,1,0,0,0],
        [0,1,0,1,0,0,1,0,1,0,0]
    ]
    
    static let type2Frame1 = [
        [0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,1,1,1,1,0,0,0,0],
        [0,0,1,1,1,1,1,1,0,0,0],
        [0,1,1,0,1,1,0,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,0,0,0,0,1,0,0,0],
        [0,1,0,0,1,1,0,0,1,0,0],
        [0,0,1,0,0,0,0,1,0,0,0]
    ]
    
    static func sprite(type: Int, frame: Int) -> [[Int]] {
        switch (type, frame) {
        case (0, 0): return type0Frame0
        case (0, 1): return type0Frame1
        case (1, 0): return type1Frame0
        case (1, 1): return type1Frame1
        case (2, 0): return type2Frame0
        case (2, 1): return type2Frame1
        default: return type0Frame0
        }
    }
    
    static func color(type: Int) -> Color {
        switch type {
        case 0: return RetroColors.neonGreen
        case 1: return RetroColors.neonBlue
        case 2: return RetroColors.neonPurple
        default: return RetroColors.neonGreen
        }
    }
}

// MARK: - Player Ship Sprite
struct PlayerSprite {
    static let pixels = [
        [0,0,0,0,0,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,0,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,0,0,0,0,0,1,1,0]
    ]
}

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

// MARK: - Particle View
struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        Group {
            switch particle.type {
            case .shockwave:
                Circle()
                    .stroke(particle.color, lineWidth: 3)
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: 2)
                    .opacity(particle.alpha)
                    .position(particle.position)
                
            case .explosion, .spark:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: particle.type == .explosion ? 2 : 1)
                    .opacity(particle.alpha)
                    .rotationEffect(.degrees(particle.rotation))
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
                    .blur(radius: 3)
                    .opacity(particle.alpha * 0.5)
                    .position(particle.position)
                
            case .star:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.alpha)
                    .position(particle.position)
            }
        }
    }
}

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

// MARK: - Menu View
struct MenuView: View {
    let gameTime: Double
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Title
            VStack(spacing: 5) {
                Text("GALAXY")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [RetroColors.neonPink, RetroColors.neonPurple, RetroColors.neonBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: RetroColors.neonPink, radius: 20)
                    .shadow(color: RetroColors.neonPurple, radius: 40)
                
                Text("INVADERS")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [RetroColors.neonGreen, RetroColors.neonBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: RetroColors.neonGreen, radius: 15)
            }
            .scaleEffect(1 + 0.02 * sin(gameTime * 2))
            
            // Demo invaders
            HStack(spacing: 30) {
                ForEach(0..<3, id: \.self) { type in
                    PixelShape(pixels: InvaderSprites.sprite(type: type, frame: Int(gameTime * 2) % 2))
                        .fill(InvaderSprites.color(type: type))
                        .frame(width: 40, height: 40)
                        .shadow(color: InvaderSprites.color(type: type), radius: 10)
                        .offset(y: 5 * sin(gameTime * 3 + Double(type)))
                }
            }
            .padding(.vertical, 20)
            
            // Start button
            Button(action: onStart) {
                Text("TAP TO START")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(RetroColors.neonGreen)
                            .shadow(color: RetroColors.neonGreen, radius: 15)
                    )
            }
            .opacity(0.7 + 0.3 * sin(gameTime * 4))
            
            // Instructions
            VStack(spacing: 10) {
                Text("DRAG TO MOVE • TAP TO FIRE")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(RetroColors.retroWhite.opacity(0.6))
            }
            .padding(.top, 30)
        }
    }
}

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
                    if engine.gameState == .playing {
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
                    
                    // Game over overlay
                    if engine.gameState == .gameOver || engine.gameState == .victory {
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

// MARK: - Content View
struct ContentView: View {
    var body: some View {
        GameView()
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ContentView()
}
