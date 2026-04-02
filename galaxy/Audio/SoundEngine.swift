//
//  SoundEngine.swift
//  galaxy
//

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
    
    func playIntergalacticExplosion() {
        guard isReady, let format = format else { return }
        
        // Phase 1: Deep rumbling bass explosion (long, dramatic)
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let duration = 2.5
        let frameCount = Int(duration * sampleRate)
        
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else { return }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let progress = time / duration
            
            // Layer 1: Deep sub-bass rumble that drops in pitch
            let bassFreq = 80.0 * (1.0 - progress * 0.6)
            let bass = sin(time * bassFreq * 2 * .pi) * 0.3
            
            // Layer 2: Mid noise explosion burst
            let noise = Double(Float.random(in: -1...1))
            let noiseEnv = max(0, 1.0 - progress * 1.5)
            let noisePart = noise * noiseEnv * noiseEnv * 0.4
            
            // Layer 3: Rising whistle/beam sound
            let beamFreq = 200.0 + progress * 800.0
            let beamEnv = progress < 0.3 ? (progress / 0.3) : max(0, 1.0 - (progress - 0.3) / 0.7)
            let beam = sin(time * beamFreq * 2 * .pi) * beamEnv * 0.15
            
            // Layer 4: Metallic ring (harmonic series)
            let ringEnv = max(0, 1.0 - progress * 0.8)
            let ring = (sin(time * 440 * 2 * .pi) * 0.5 +
                        sin(time * 554 * 2 * .pi) * 0.3 +
                        sin(time * 660 * 2 * .pi) * 0.2) * ringEnv * ringEnv * 0.1
            
            // Layer 5: Descending dramatic notes
            let noteProgress = progress * 4
            let noteIndex = Int(noteProgress) % 4
            let noteFreqs = [293.66, 261.63, 220.0, 164.81]  // D4, C4, A3, E3
            let noteEnv = max(0, 1.0 - (noteProgress - floor(noteProgress)) * 2.0)
            let notePart = sin(time * noteFreqs[noteIndex] * 2 * .pi) * noteEnv * 0.12 * (progress < 0.8 ? 1.0 : 0.0)
            
            // Overall envelope: sharp attack, long decay
            let attack = min(1.0, time / 0.01)
            let decay = max(0, 1.0 - progress * progress * 0.5)
            let masterVol = attack * decay * 0.8
            
            let sample = Float((bass + noisePart + beam + ring + notePart) * masterVol)
            
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
        
        // Use multiple nodes for the big explosion sound
        let node = playerNodes[currentNodeIndex]
        currentNodeIndex = (currentNodeIndex + 1) % nodeCount
        
        if node.isPlaying {
            node.stop()
        }
        
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
        
        // Additional crackle overlay on another node
        let crackleDuration = 1.5
        let crackleFrameCount = Int(crackleDuration * sampleRate)
        guard crackleFrameCount > 0,
              let crackleBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(crackleFrameCount)),
              let crackleData = crackleBuffer.floatChannelData else { return }
        
        crackleBuffer.frameLength = AVAudioFrameCount(crackleFrameCount)
        
        for frame in 0..<crackleFrameCount {
            let time = Double(frame) / sampleRate
            let progress = time / crackleDuration
            
            // Random crackle pops
            var sample: Float = 0
            if Float.random(in: 0...1) < Float(0.3 * (1.0 - progress)) {
                sample = Float.random(in: -0.5...0.5) * Float(1.0 - progress)
            }
            // Filtered rumble
            let rumble = sin(time * 40 * 2 * .pi) * (1.0 - progress) * 0.2
            sample += Float(rumble)
            sample *= Float(0.5)
            
            for channel in 0..<channelCount {
                crackleData[channel][frame] = sample
            }
        }
        
        let crackleNode = playerNodes[currentNodeIndex]
        currentNodeIndex = (currentNodeIndex + 1) % nodeCount
        
        if crackleNode.isPlaying {
            crackleNode.stop()
        }
        
        crackleNode.scheduleBuffer(crackleBuffer, at: nil, options: [], completionHandler: nil)
        crackleNode.play()
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
