//
//  WelcomeHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 12.09.25.
//

import SwiftUI
/*
struct WelcomeHeader: View {
    let username: String
    let nowPlaying: Song?
    
    @State private var rainbowShift = false
    @State private var cosmicPulse = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 🌈 LSD-Gradient Title
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greetingText())
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple, .blue, .green, .yellow],
                                startPoint: rainbowShift ? .topLeading : .bottomTrailing,
                                endPoint: rainbowShift ? .bottomTrailing : .topLeading
                            )
                        )
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: rainbowShift)
                    
                    if let track = nowPlaying {
                        Text("Currently vibing with:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("🎶 \(track.title) – \(track.artist)")
                            .font(.callout.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text("No track right now – the silence hums 🌌")
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 🌀 Cosmic Orb Clock
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [.pink, .purple, .blue, .green, .yellow, .pink]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(cosmicPulse ? 360 : 0))
                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: cosmicPulse)
                    
                    Text(currentTimeString())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
            
            // ✨ Animated underline wave
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .blue.opacity(0.5), .green.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .cornerRadius(1)
                .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onAppear {
            rainbowShift = true
            cosmicPulse = true
        }
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "☀️ Good Morning, Cosmic Traveler \(username)"
        case 12..<17: return "🌻 Afternoon Vibrations, \(username)"
        case 17..<22: return "🌙 Good Evening, Dreamer \(username)"
        default: return "✨ Midnight Frequencies, \(username)"
        }
    }
    
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
*/

// Less intrusive
import SwiftUI

struct WelcomeHeader: View {
    let username: String
    let nowPlaying: Song?

    @State private var showingNetworkTestView = false
    @State private var showingCoverArtDebugView = false
    
    // MARK: - Mehrsprachige Grüße nach Tageszeit
    private let greetingsByTime: [String: [String]] = [
        "morning": ["Good morning", "Bonjour", "Guten Morgen", "おはようございます", "Buongiorno"],
        "afternoon": ["Good afternoon", "Bon après-midi", "Guten Tag", "Buenas tardes", "Buon pomeriggio"],
        "evening": ["Good evening", "Bonsoir", "Guten Abend", "Buonasera", "こんばんは"],
        "night": ["Good night", "Bonne nuit", "Gute Nacht", "おやすみなさい", "Buonanotte"]
    ]

    // MARK: - Zitate
    private let musicQuotes: [String] = [
        "Where words fail, music speaks. – Hans Christian Andersen",
        "One good thing about music, when it hits you, you feel no pain. – Bob Marley",
        "Without music, life would be a mistake. – Friedrich Nietzsche",
        "Music can change the world. – Ludwig van Beethoven",
        "Music is the shorthand of emotion. – Leo Tolstoy",
        "Life is like a piano, what you get out of it depends on how you play it. – Tom Lehrer",
        "Music is the strongest form of magic. – Marilyn Manson",
        "Music is love in search of a word. – Sidney Lanier",
        "Music is the universal language of mankind. – Henry Wadsworth Longfellow",
        "Music is the heartbeat of the world. – Unknown",
        "Without music, the world would be silent. – Unknown",
        "Music expresses that which cannot be put into words. – Victor Hugo",
        "Where words leave off, music begins. – Heinrich Heine",
        "Music washes away from the soul the dust of everyday life. – Berthold Auerbach",
        "Music is the art which is most nigh to tears and memory. – Oscar Wilde",
        "Music is the mediator between the spiritual and the sensual life. – Ludwig van Beethoven",
        "Music is a safe kind of high. – Jimi Hendrix",
        "The only truth is music. – Jack Kerouac",
        "Music is the poetry of the air. – Richter",
        "Music is the divine way to tell beautiful, poetic things to the heart. – Pablo Casals",
        "Music is the moonlight in the gloomy night of life. – Jean Paul",
        "If music be the food of love, play on. – William Shakespeare",
        "Music produces a kind of pleasure which human nature cannot do without. – Confucius",
        "Music gives a soul to the universe, wings to the mind, flight to the imagination. – Plato",
        "Music is life itself. – Louis Armstrong",
        "Music is the great uniter. An incredible force. Something that people who differ on everything and anything else can have in common. – Sarah Dessen",
        "Music is a world within itself; it’s a language we all understand. – Stevie Wonder",
        "Music is the key to the soul. – Unknown",
        "Music is what feelings sound like. – Unknown",
        "Music is the soundtrack of your life. – Dick Clark",
        "Music is the strongest form of magic. – Marilyn Manson",
        "Music is the literature of the heart; it commences where speech ends. – Alphonse de Lamartine",
        "Music is the art of thinking with sounds. – Jules Combarieu",
        "Music is the great balm for the soul. – Unknown",
        "Music is the divine way to tell beautiful, poetic things to the heart. – Pablo Casals",
        "Music is the movement of sound to reach the soul for the education of its virtue. – Plato",
        "Music is the sound of life. – Unknown",
        "Music is the balm that heals the forlorn ache of a distant star. – Lang Leav",
        "Music is the voice of the soul. – Unknown",
        "Music is the wine that fills the cup of silence. – Robert Fripp",
        "Music is the emotional life of most people. – Leonard Bernstein",
        "Music is a higher revelation than all wisdom and philosophy. – Ludwig van Beethoven",
        "Music is the great unifier. – Unknown",
        "Music is the ultimate art form. – Unknown",
        "Music is the divine way to tell beautiful, poetic things to the heart. – Pablo Casals",
        "Music is a safe kind of high. – Jimi Hendrix",
        "Music is my religion. – Jimi Hendrix",
        "Music is the mediator between the spiritual and sensual life. – Ludwig van Beethoven",
        "Music is the language of the spirit. – Kahlil Gibran"
    ]

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            // Hintergrundgradient
            LinearGradient(
                colors: gradientColors(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .horizontal)
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 8, y: 4)

            // Inhalt
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(timeBasedGreeting()), \(username)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text(randomQuote())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                
                Button (action: {
                    showingCoverArtDebugView.toggle()
                })
                {
                    Text("click me")
                }
                .sheet(isPresented: $showingCoverArtDebugView){
                    CoverArtDebugView() // deine View, die aufgehen soll
                }

                
                
                
                Spacer()
                
                Button(action: {
                    // z. B. ein Sheet öffnen
                    showingNetworkTestView.toggle()
                }) {
                    Image(systemName: nowPlaying == nil ? "music.note" : "waveform")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding()
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .sheet(isPresented: $showingNetworkTestView){
                    NetworkTestView() // deine View, die aufgehen soll
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Helper Methods
    private func gradientColors() -> [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return [Color.orange, Color.pink]
        case 12..<17: return [Color.blue, Color.cyan]
        case 17..<22: return [Color.purple, Color.indigo]
        default: return [Color.black, Color.teal]
        }
    }

    private func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeKey: String
        switch hour {
        case 5..<12: timeKey = "morning"
        case 12..<17: timeKey = "afternoon"
        case 17..<22: timeKey = "evening"
        default: timeKey = "night"
        }
        return greetingsByTime[timeKey]?.randomElement() ?? "Hello"
    }

    private func randomQuote() -> String {
        musicQuotes.randomElement() ?? "Enjoy your music!"
    }
}

