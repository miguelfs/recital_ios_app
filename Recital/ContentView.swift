//
//  ContentView.swift
//  Recital
//
//  Created by Miguel Sousa on 02/05/25.
//

import AVFoundation
import SwiftUI

// Custom button style that provides haptic feedback on press only when starting recording
struct HapticButtonStyle: ButtonStyle {
    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
    var isRecording: Bool  // Add recording state to control when feedback happens
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Preserve the default pressing effect (opacity change)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            // Add a slight scale effect for press visual feedback
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            // Animate the scale change
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                // Only provide haptic feedback when starting a recording (not when stopping)
                if newValue && !isRecording {  // Pressed down AND not already recording
                    let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
                    generator.prepare()
                    generator.impactOccurred()
                }
            }
    }
}

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 30) {
            // Title only appears when not recording for cleaner UI
            if !audioRecorder.isRecording {
                Text("Recital")
                    .font(.system(size: 48, weight: .thin, design: .monospaced))
                    .foregroundColor(.purple.opacity(0.8))
                    .padding(.top, 20)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            }

            ZStack {
                // Background circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 280, height: 280)

                // Audio level visualization bubbles
                if audioRecorder.isRecording {
                    // Base pulse circle that's always visible
                    Circle()
                        .stroke(audioRecorder.frequencyColor.opacity(0.7), lineWidth: 3)
                        .frame(width: 270, height: 270)

                    // Multiple animated circles based on audio level
                    ForEach(1...5, id: \.self) { index in
                        let delay = Double(index) / 10.0

                        Circle()
                            .stroke(
                                audioRecorder.frequencyColor.opacity(0.7 - Double(index) * 0.1),
                                lineWidth: 3
                            )
                            .frame(
                                width: 140 + (audioRecorder.audioLevel * 150) * CGFloat(index) / 3,
                                height: 140 + (audioRecorder.audioLevel * 150) * CGFloat(index) / 3
                            )
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
                                    .delay(delay), value: audioRecorder.audioLevel
                            )
                            .animation(
                                .easeInOut(duration: 0.3).delay(delay),
                                value: audioRecorder.frequencyColor)
                    }

                    // Debug info for frequency (optional - can be removed)
                    Text("Freq: \(Int(audioRecorder.dominantFrequency)) Hz")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .opacity(0.7)
                        .offset(y: -140)
                }

                // Recording button
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    ZStack {
                        // Button background with gradient - using if/else to avoid transition
                        if audioRecorder.isRecording {
                            // Recording state background (red/orange)
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .orange.opacity(0.8)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                                // Only animate scale/opacity changes from button press, not color changes
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                        } else {
                            // Ready to record state background (blue/purple)
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple.opacity(0.8)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                                // Only animate scale/opacity changes from button press, not color changes
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                        }

                        // Button icon - using direct conditional to prevent any transitions
                        if audioRecorder.isRecording {
                            // Stop icon - no animation
                            Image(systemName: "stop.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                                .transaction { transaction in
                                    // Explicitly disable animations for this view
                                    transaction.animation = nil
                                }
                        } else {
                            // Mic icon - no animation
                            Image(systemName: "mic.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                                .transaction { transaction in
                                    // Explicitly disable animations for this view
                                    transaction.animation = nil
                                }
                        }
                    }
                }
                .buttonStyle(HapticButtonStyle(feedbackStyle: .medium, isRecording: audioRecorder.isRecording)) // Apply haptic style with recording state
                .disabled(audioRecorder.isPlaying)
            }
            .padding()
            .frame(height: 350)

            // Playback button with improved styling
            // Only show when we have a recording AND we're not currently recording
            if audioRecorder.audioURL != nil && !audioRecorder.isRecording {
                Button(action: {
                    if audioRecorder.isPlaying {
                        audioRecorder.stopPlayback()
                    } else {
                        audioRecorder.startPlayback()
                    }
                }) {
                    HStack(spacing: 12) {
                        // Fixed-width container to ensure icon alignment
                        ZStack {
                            // Ensure both icons are perfectly centered in the same space
                            if audioRecorder.isPlaying {
                                Image(systemName: "stop.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(width: 30, height: 30)

                        Text(audioRecorder.isPlaying ? "Stop Playback" : "Play Recording")
                            .font(.headline)
                            .foregroundColor(audioRecorder.isPlaying ? .red : .green)
                    }
                    .frame(height: 50)
                    .frame(minWidth: 200)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)  // Add a smooth transition when appearing/disappearing
                .padding(.bottom, 20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    ContentView()
}
