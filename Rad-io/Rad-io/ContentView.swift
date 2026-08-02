//
//  ContentView.swift
//  Rad-io
//
//  Created by Elliot Williams on 2025-05-31.
//

import SwiftUI
import AVFoundation
import Accelerate
import MediaPlayer
import CoreGraphics
import Foundation

// MARK: - Data Model
struct RadioStation: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let genre: String
    let colorHex: String
    let streamURL: URL
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    static let sampleStations = [
        RadioStation(name: "Electric Beats", genre: "EDM", colorHex: "#9B5DE5", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Rock Legends", genre: "Rock", colorHex: "#F15BB5", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!),
        RadioStation(name: "Chill Waves", genre: "Ambient", colorHex: "#00BBF9", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Hip-Hop Central", genre: "Hip-Hop", colorHex: "#FEE440", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!),
        RadioStation(name: "Jazz Lounge", genre: "Jazz", colorHex: "#00F5D4", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Classical Gold", genre: "Classical", colorHex: "#FF6B6B", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!),
        RadioStation(name: "Country Roads", genre: "Country", colorHex: "#4ECDC4", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Latin Beats", genre: "Latin", colorHex: "#FF9F1C", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!)
    ]
}

// MARK: - Particle System
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var color: Color
    var life: CGFloat
    var maxLife: CGFloat
    
    init(x: CGFloat, y: CGFloat, color: Color) {
        self.x = x
        self.y = y
        self.vx = CGFloat.random(in: -2...2)
        self.vy = CGFloat.random(in: -3...1)
        self.size = CGFloat.random(in: 2...8)
        self.color = color
        self.life = 1.0
        self.maxLife = CGFloat.random(in: 2...5)
    }
    
    mutating func update() {
        x += vx
        y += vy
        life -= 0.02
        vy -= 0.1 // Gravity
    }
    
    var isAlive: Bool {
        life > 0
    }
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var timer: Timer?
    
    func startEmitting(with analyzer: AudioAnalyzer, color: Color) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateParticles(analyzer: analyzer, color: color)
        }
    }
    
    func stopEmitting() {
        timer?.invalidate()
        timer = nil
        particles.removeAll()
    }
    
    private func updateParticles(analyzer: AudioAnalyzer, color: Color) {
        // Remove dead particles
        particles = particles.filter { $0.isAlive }
        
        // Update existing particles
        for i in 0..<particles.count {
            particles[i].update()
        }
        
        // Add new particles based on audio intensity
        let intensity = analyzer.overallLevel
        let particleCount = Int(intensity * 5)
        
        for _ in 0..<particleCount {
            let x = CGFloat.random(in: 0...400)
            let y = CGFloat.random(in: 600...800)
            let particleColor = [color, color.opacity(0.7), Color.white.opacity(0.5)].randomElement()!
            particles.append(Particle(x: x, y: y, color: particleColor))
        }
        
        // Limit particle count
        if particles.count > 200 {
            particles.removeFirst(particles.count - 200)
        }
    }
}

// MARK: - Audio Analyzer with Enhanced Dynamics
class AudioAnalyzer: ObservableObject {
    @Published var magnitudes: [Float] = Array(repeating: 0.0, count: 16)
    @Published var bassLevel: Float = 0.0
    @Published var midLevel: Float = 0.0
    @Published var trebleLevel: Float = 0.0
    @Published var overallLevel: Float = 0.0
    
    private let fftSize = 1024
    private let bands = 16
    
    func simulateAudioAnalysis() {
        // Enhanced audio-like values with different frequency bands
        var simulatedMagnitudes = [Float]()
        let time = Float(Date().timeIntervalSince1970)
        
        // Bass (0-3), Mid (4-10), Treble (11-15)
        for i in 0..<16 {
            let baseValue = Float.random(in: 0.05...0.15)
            let frequency = Float(i + 1) * 0.5
            var peakValue: Float
            if i < 4 { // Bass
                peakValue = Foundation.sin(time * frequency * 0.3) * 0.4 + 0.4
            } else if i < 11 { // Mid
                peakValue = Foundation.sin(time * frequency * 0.6) * 0.3 + 0.3
            } else { // Treble
                peakValue = Foundation.sin(time * frequency * 1.2) * 0.2 + 0.2
            }
            peakValue += Float.random(in: -0.1...0.1)
            let value = max(baseValue, min(peakValue, 1.0))
            simulatedMagnitudes.append(value)
        }
        
        magnitudes = simulatedMagnitudes
        
        // Frequency band levels
        bassLevel = magnitudes[0..<4].reduce(0, +) / 4.0
        midLevel = magnitudes[4..<11].reduce(0, +) / 7.0
        trebleLevel = magnitudes[11..<16].reduce(0, +) / 5.0
        overallLevel = magnitudes.reduce(0, +) / Float(magnitudes.count)
    }
}

// MARK: - Radio Player with Background Support
class RadioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentStation: RadioStation?
    @Published var favoriteStations: [RadioStation] = []
    @Published var analyzer = AudioAnalyzer()
    @Published var particleSystem = ParticleSystem()
    
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    
    override init() {
        super.init()
        loadFavorites()
        setupRemoteTransportControls()
        setupAudioSession()
    }
    
    // Setup audio session for background playback
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }
    
    // Setup lock screen controls
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.resume()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextStation()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousStation()
            return .success
        }
    }
    
    // Update now playing info for lock screen
    private func updateNowPlayingInfo() {
        guard let station = currentStation else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = station.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = station.genre
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // Play a station
    func play(station: RadioStation) {
        stop()
        currentStation = station
        
        audioPlayer = AVPlayer(url: station.streamURL)
        audioPlayer?.play()
        isPlaying = true
        
        // Add periodic observer for audio analysis
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { [weak self] _ in
            self?.analyzer.simulateAudioAnalysis()
        }
        
        // Start particle system
        particleSystem.startEmitting(with: analyzer, color: station.color)
        
        updateNowPlayingInfo()
    }
    
    // Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        analyzer.magnitudes = Array(repeating: 0.1, count: 16)
        analyzer.bassLevel = 0.1
        analyzer.midLevel = 0.1
        analyzer.trebleLevel = 0.1
        analyzer.overallLevel = 0.1
        particleSystem.stopEmitting()
    }
    
    // Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        if let station = currentStation {
            particleSystem.startEmitting(with: analyzer, color: station.color)
        }
    }
    
    // Stop playback
    func stop() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        analyzer.magnitudes = Array(repeating: 0.1, count: 16)
        analyzer.bassLevel = 0.1
        analyzer.midLevel = 0.1
        analyzer.trebleLevel = 0.1
        analyzer.overallLevel = 0.1
        particleSystem.stopEmitting()
    }
    
    // Toggle play/pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else if let station = currentStation {
            play(station: station)
        }
    }
    
    // Favorites management
    func toggleFavorite(station: RadioStation) {
        if favoriteStations.contains(station) {
            favoriteStations.removeAll { $0.id == station.id }
        } else {
            favoriteStations.append(station)
        }
        saveFavorites()
    }
    
    func isFavorite(station: RadioStation) -> Bool {
        favoriteStations.contains(station)
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteStations) {
            UserDefaults.standard.set(encoded, forKey: "favoriteStations")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favoriteStations"),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            favoriteStations = decoded
        }
    }
    
    // Navigation
    func nextStation() {
        guard let current = currentStation else { return }
        let allStations = RadioStation.sampleStations
        if let index = allStations.firstIndex(of: current) {
            let nextIndex = (index + 1) % allStations.count
            play(station: allStations[nextIndex])
        }
    }
    
    func previousStation() {
        guard let current = currentStation else { return }
        let allStations = RadioStation.sampleStations
        if let index = allStations.firstIndex(of: current) {
            let prevIndex = (index - 1 + allStations.count) % allStations.count
            play(station: allStations[prevIndex])
        }
    }
}

// MARK: - RAD Visual Components
struct ParticleView: View {
    @ObservedObject var particleSystem: ParticleSystem
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particleSystem.particles) { particle in
                ZStack {
                    // Neon glow effect
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size * 3, height: particle.size * 3)
                        .opacity(Double(particle.life) * 0.2)
                        .blur(radius: particle.size * 0.8)
                    
                    // Core particle
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(Double(particle.life))
                        .shadow(color: particle.color, radius: 5)
                }
                .position(x: particle.x, y: particle.y)
            }
        }
        .allowsHitTesting(false)
    }
}

struct RadAnimatedBackground: View {
    @ObservedObject var analyzer: AudioAnalyzer
    var color: Color
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var neonIntensity: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Rad gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.purple.opacity(0.3),
                        Color.cyan.opacity(0.2),
                        Color.black
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Neon grid effect
                RadNeonGrid(analyzer: analyzer, color: color, offset: animationOffset)
                
                // Holographic circles
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [color, Color.cyan, Color.magenta, color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3 + CGFloat(analyzer.overallLevel) * 5
                        )
                        .frame(
                            width: 80 + CGFloat(index) * 40 + CGFloat(analyzer.overallLevel) * 120,
                            height: 80 + CGFloat(index) * 40 + CGFloat(analyzer.overallLevel) * 120
                        )
                        .position(
                            x: geometry.size.width * 0.5 + Foundation.sin(animationOffset + Double(index) * 0.5) * 150,
                            y: geometry.size.height * 0.5 + Foundation.cos(animationOffset + Double(index) * 0.7) * 100
                        )
                        .shadow(color: color, radius: 10 + CGFloat(analyzer.overallLevel) * 20)
                        .scaleEffect(pulseScale + CGFloat(analyzer.overallLevel) * 0.3)
                        .opacity(0.4 + Double(analyzer.overallLevel) * 0.6)
                }
                
                // Radical wave effects
                ForEach(0..<5, id: \.self) { waveIndex in
                    RadWaveShape(
                        frequency: Double(waveIndex + 1) * 0.3,
                        amplitude: Double(analyzer.magnitudes[min(waveIndex * 3, 15)]) * 80,
                        phase: animationOffset,
                        bassBoost: Double(analyzer.bassLevel)
                    )
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.8), color, Color.magenta.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                    .shadow(color: color, radius: 8)
                    .blur(radius: 0.5)
                }
                
                // Laser beam effects
                ForEach(0..<3, id: \.self) { beamIndex in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, color.opacity(0.8), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 2, height: 4)
                        .rotationEffect(.degrees(animationOffset * 30 + Double(beamIndex) * 60))
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
                        .opacity(Double(analyzer.overallLevel) * 0.6)
                        .blur(radius: 1)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startRadAnimation()
        }
    }
    
    private func startRadAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            withAnimation(.linear(duration: 0.016)) {
                animationOffset += 0.03
                pulseScale = 1.0 + Foundation.sin(animationOffset * 3) * 0.15
                neonIntensity = 0.8 + Foundation.sin(animationOffset * 4) * 0.2
            }
        }
    }
}

struct RadNeonGrid: View {
    @ObservedObject var analyzer: AudioAnalyzer
    var color: Color
    var offset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal grid lines
                ForEach(0..<15, id: \.self) { index in
                    let baseOpacity = 0.3
                    let dynamicOpacity = Double(analyzer.overallLevel) * 0.4
                    let totalOpacity = baseOpacity + dynamicOpacity
                    let lineColor = color.opacity(totalOpacity)
                    
                    let baseY = CGFloat(index) * geometry.size.height / 15
                    let waveOffset = Foundation.sin(offset + Double(index) * 0.3) * 20
                    let finalY = baseY + waveOffset
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, lineColor, Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 1)
                        .position(
                            x: geometry.size.width * 0.5,
                            y: finalY
                        )
                        .shadow(color: color, radius: 3)
                }
                
                // Vertical grid lines
                ForEach(0..<20, id: \.self) { index in
                    let verticalBaseOpacity = 0.2
                    let verticalDynamicOpacity = Double(analyzer.overallLevel) * 0.3
                    let verticalTotalOpacity = verticalBaseOpacity + verticalDynamicOpacity
                    let verticalLineColor = color.opacity(verticalTotalOpacity)
                    
                    let baseX = CGFloat(index) * geometry.size.width / 20
                    let horizontalWaveOffset = Foundation.cos(offset + Double(index) * 0.2) * 15
                    let finalX = baseX + horizontalWaveOffset
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, verticalLineColor, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1, height: geometry.size.height)
                        .position(
                            x: finalX,
                            y: geometry.size.height * 0.5
                        )
                        .shadow(color: color, radius: 2)
                }
            }
        }
        .opacity(0.6)
    }
}

struct RadWaveShape: Shape {
    var frequency: Double
    var amplitude: Double
    var phase: Double
    var bassBoost: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let waveY = Foundation.sin(relativeX * frequency * 2 * .pi + phase) * amplitude
            let bassEffect = Foundation.sin(relativeX * 4 * .pi + phase * 2) * bassBoost * 30
            let y = waveY + bassEffect + midHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct EnhancedStationCard: View {
    let station: RadioStation
    var isPlaying: Bool
    var isFavorite: Bool
    var onPlay: () -> Void
    var onFavorite: () -> Void
    @ObservedObject var analyzer: AudioAnalyzer
    @State private var cardScale: CGFloat = 1.0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(station.genre)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            
            // Mini rad equalizer for playing station
            if isPlaying {
                RadEqualizerView(analyzer: analyzer, color: .white, size: 20)
                    .frame(width: 80)
            }
            
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isFavorite ? .red : .white)
                    .padding(.trailing, 10)
                    .scaleEffect(isFavorite ? 1.2 : 1.0)
                    .animation(.bouncy(duration: 0.3), value: isFavorite)
            }
            
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .scaleEffect(isPlaying ? 1.1 : 1.0)
                    .animation(.bouncy(duration: 0.3), value: isPlaying)
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(station.color.gradient)
                    .shadow(color: station.color.opacity(0.6), radius: 10, x: 0, y: 5)
                
                if isPlaying {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(station.color.opacity(0.8), lineWidth: 2)
                        .blur(radius: 1)
                        .scaleEffect(cardScale)
                }
            }
        )
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.3), value: isPlaying)
        .onAppear {
            if isPlaying {
                startPulseAnimation()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startPulseAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.1)) {
                    cardScale = 1.0 + CGFloat(analyzer.overallLevel) * 0.1
                }
            } else {
                timer.invalidate()
                cardScale = 1.0
            }
        }
    }
}

// MARK: - UI Components
struct StationCard: View {
    let station: RadioStation
    var isPlaying: Bool
    var isFavorite: Bool
    var onPlay: () -> Void
    var onFavorite: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(station.genre)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isFavorite ? .red : .white)
                    .padding(.trailing, 10)
            }
            
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(station.color.gradient)
                .shadow(color: station.color.opacity(0.6), radius: 10, x: 0, y: 5)
        )
    }
}

struct RadEqualizerView: View {
    @ObservedObject var analyzer: AudioAnalyzer
    var color: Color
    var size: CGFloat = 30
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<analyzer.magnitudes.count, id: \.self) { index in
                let barHeight = size * CGFloat(analyzer.magnitudes[index])
                let barColor = getRadBarColor(for: index)
                
                ZStack {
                    // Neon glow effect
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: 8, height: max(barHeight * 1.5, 4))
                        .blur(radius: 4)
                        .opacity(0.6)
                    
                    // Core bar with holographic effect
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.9), Color.white.opacity(0.8), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 5, height: max(barHeight, 3))
                        .shadow(color: barColor, radius: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .animation(.spring(response: 0.1, dampingFraction: 0.2), value: analyzer.magnitudes[index])
            }
        }
        .frame(height: size)
        .onAppear {
            startGlowAnimation()
        }
    }
    
    private func getRadBarColor(for index: Int) -> Color {
        let intensity = analyzer.magnitudes[index]
        if index < 4 { // Bass - Rad purple/pink
            return Color.purple.opacity(0.4 + Double(intensity) * 0.6)
        } else if index < 11 { // Mid - Electric blue/cyan
            return Color.cyan.opacity(0.4 + Double(intensity) * 0.6)
        } else { // Treble - Neon green/yellow
            return Color.green.opacity(0.4 + Double(intensity) * 0.6)
        }
    }
    
    private func startGlowAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                glowIntensity = 0.3 + Double(analyzer.overallLevel) * 0.7
            }
        }
    }
}

struct PlayerControls: View {
    @ObservedObject var player: RadioPlayer
    
    var body: some View {
        VStack {
            if let station = player.currentStation {
                HStack {
                    VStack(alignment: .leading) {
                        Text(station.name)
                            .font(.title3.bold())
                            .lineLimit(1)
                        Text(station.genre)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if player.isPlaying {
                        RadEqualizerView(analyzer: player.analyzer, color: station.color)
                            .frame(width: 120)
                    }
                    
                    Button(action: player.togglePlayback) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(station.color)
                    }
                }
                
                HStack {
                    Button(action: player.previousStation) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(station.color)
                    }
                    .padding(.trailing, 30)
                    
                    Button(action: {
                        player.toggleFavorite(station: station)
                    }) {
                        Image(systemName: player.isFavorite(station: station) ? "heart.fill" : "heart")
                            .font(.title)
                            .foregroundColor(player.isFavorite(station: station) ? .red : station.color)
                    }
                    
                    Button(action: player.nextStation) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(station.color)
                    }
                    .padding(.leading, 30)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

struct StationListView: View {
    @ObservedObject var player: RadioPlayer
    var stations: [RadioStation]
    var title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)
                .shadow(color: .white.opacity(0.3), radius: 5)
            
            ForEach(stations) { station in
                EnhancedStationCard(
                    station: station,
                    isPlaying: player.currentStation == station && player.isPlaying,
                    isFavorite: player.isFavorite(station: station),
                    onPlay: { player.play(station: station) },
                    onFavorite: { player.toggleFavorite(station: station) },
                    analyzer: player.analyzer
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Main View
struct RadioView: View {
    @StateObject private var player = RadioPlayer()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // RAD animated background
            if let currentStation = player.currentStation {
                RadAnimatedBackground(
                    analyzer: player.analyzer,
                    color: currentStation.color
                )
            } else {
                RadAnimatedBackground(
                    analyzer: player.analyzer,
                    color: .purple
                )
            }
            
            // Particle effects
            ParticleView(particleSystem: player.particleSystem)
            
            VStack(spacing: 0) {
                // RAD Header
                ZStack {
                    Text("RAD-IO")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(
                                colors: [Color.cyan, Color.magenta, Color.yellow, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .mask(
                                Text("RAD-IO")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                            )
                        )
                        .shadow(color: .cyan, radius: 20)
                        .shadow(color: .magenta, radius: 10)
                    
                    Text("RAD-IO")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .blur(radius: 1)
                        .opacity(0.3)
                }
                .padding(.top, 30)
                .scaleEffect(1.0 + CGFloat(player.analyzer.overallLevel) * 0.1)
                .animation(.easeInOut(duration: 0.1), value: player.analyzer.overallLevel)
                
                // Tab selector
                HStack {
                    TabButton(title: "All Stations", index: 0, selectedTab: $selectedTab)
                    TabButton(title: "Favorites", index: 1, selectedTab: $selectedTab)
                    TabButton(title: "Playing", index: 2, selectedTab: $selectedTab)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    ScrollView {
                        StationListView(
                            player: player,
                            stations: RadioStation.sampleStations,
                            title: "All Stations"
                        )
                        .padding(.top, 20)
                    }
                    .tag(0)
                    
                    ScrollView {
                        if player.favoriteStations.isEmpty {
                            Text("No favorites yet\nTap the heart icon to add stations")
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.top, 100)
                        } else {
                            StationListView(
                                player: player,
                                stations: player.favoriteStations,
                                title: "Favorite Stations"
                            )
                            .padding(.top, 20)
                        }
                    }
                    .tag(1)
                    
                    ScrollView {
                        if let currentStation = player.currentStation {
                            VStack {
                                ZStack {
                                    // Rad holographic disc
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    currentStation.color.opacity(0.8),
                                                    Color.cyan.opacity(0.6),
                                                    Color.magenta.opacity(0.4),
                                                    currentStation.color.opacity(0.9)
                                                ],
                                                center: .center,
                                                startRadius: 50,
                                                endRadius: 120
                                            )
                                        )
                                        .frame(width: 240, height: 240)
                                        .shadow(color: currentStation.color, radius: 30)
                                        .shadow(color: .cyan, radius: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.8), Color.clear, Color.white.opacity(0.5)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                        )
                                        .scaleEffect(1.0 + CGFloat(player.analyzer.overallLevel) * 0.2)
                                        .rotationEffect(.degrees(player.isPlaying ? 360 : 0))
                                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: player.isPlaying)
                                    
                                    // Inner holographic ring
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.cyan, Color.magenta, Color.yellow, Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 4
                                        )
                                        .frame(width: 100, height: 100)
                                        .shadow(color: .cyan, radius: 10)
                                        .scaleEffect(1.0 + CGFloat(player.analyzer.bassLevel) * 0.3)
                                    
                                    if player.isPlaying {
                                        RadEqualizerView(analyzer: player.analyzer, color: .white, size: 80)
                                            .frame(width: 180, height: 80)
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 60))
                                            .foregroundColor(.white)
                                            .shadow(color: .cyan, radius: 10)
                                    }
                                }
                                .padding(.top, 50)
                                
                                Text(currentStation.name)
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                                    .padding(.top, 20)
                                
                                Text(currentStation.genre)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 5)
                                
                                HStack(spacing: 30) {
                                    Button(action: player.previousStation) {
                                        Image(systemName: "backward.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Circle().fill(currentStation.color))
                                    }
                                    
                                    Button(action: player.togglePlayback) {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Circle().fill(currentStation.color))
                                    }
                                    
                                    Button(action: player.nextStation) {
                                        Image(systemName: "forward.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Circle().fill(currentStation.color))
                                    }
                                }
                                .padding(.top, 30)
                                
                                Button(action: {
                                    player.toggleFavorite(station: currentStation)
                                }) {
                                    HStack {
                                        Image(systemName: player.isFavorite(station: currentStation) ? "heart.fill" : "heart")
                                        Text(player.isFavorite(station: currentStation) ? "Remove from Favorites" : "Add to Favorites")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 15).fill(currentStation.color))
                                }
                                .padding(.top, 20)
                            }
                            .padding()
                        } else {
                            Text("No station playing\nSelect a station to start listening")
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.top, 150)
                        }
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Player controls at bottom
                PlayerControls(player: player)
                    .padding(.bottom, 30)
                    .padding(.top, 10)
            }
        }
        .onAppear {
            // Set background audio session
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session setup error: \(error)")
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button(action: {
            selectedTab = index
        }) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    selectedTab == index ?
                    RoundedRectangle(cornerRadius: 15).fill(Color.purple.opacity(0.3)) :
                        RoundedRectangle(cornerRadius: 15).fill(Color.clear)
                )
        }
    }
}

// MARK: - Helper Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // RAD colors
    static let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)
    static let neonCyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 0.5)
}

// MARK: - Preview
struct RadioView_Previews: PreviewProvider {
    static var previews: some View {
        RadioView()
            .preferredColorScheme(.dark)
    }
}
