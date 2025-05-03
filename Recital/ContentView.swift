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
            .animation(.easeInOut(duration: 0.3), value: configuration.isPressed)
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
    @StateObject private var backgroundPainter = BackgroundPainter()
    @State private var viewSize: CGSize = .zero
    
    // Timer for updating background during recording
    @State private var backgroundUpdateTimer: Timer?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Canvas background that changes when recording
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Background Canvas for painting effects
                BackgroundCanvasView(painter: backgroundPainter, screenSize: geo.size)
                    .edgesIgnoringSafeArea(.all)
                
                // Main content
                VStack(spacing: 30) {
                    // Style selector - only visible when recording
                    if audioRecorder.isRecording {
                        VStack {
                            Text(backgroundPainter.currentStyle.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                )
                                .onTapGesture {
                                    backgroundPainter.cycleToNextStyle()
                                }
                        }
                        .padding(.top, 10)
                        .transition(.opacity)
                    } else {
                        // Title only appears when not recording for cleaner UI
                        Text("Recital")
                            .font(.system(size: 48, weight: .thin, design: .monospaced))
                            .foregroundColor(.purple.opacity(0.8))
                            .padding(.top, 20)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                            .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        // Fixed size container for visualization and button
                        // This ensures the button stays centered regardless of circle sizes
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 280, height: 280)
                            
                            // Audio level visualization bubbles - in a separate ZStack to isolate their sizing
                            if audioRecorder.isRecording {
                                ZStack {
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
                                }
                                
                                // Debug info for frequency (optional - can be removed)
                                Text("Freq: \(Int(audioRecorder.dominantFrequency)) Hz")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .opacity(0.7)
                                    .offset(y: -140)
                            }
                        }
                        .frame(width: 280, height: 280)  // Fixed frame to contain visualization
                        
                        // Recording button - now in a separate ZStack layer from the visualization circles
                        Button(action: {
                            if audioRecorder.isRecording {
                                stopRecording()
                            } else {
                                startRecording()
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
                            .frame(width: 110, height: 110)  // Fixed size for button
                        }
                        .buttonStyle(HapticButtonStyle(feedbackStyle: .medium, isRecording: audioRecorder.isRecording)) // Apply haptic style with recording state
                        .disabled(audioRecorder.isPlaying)
                    }
                    .padding()
                    .frame(height: 350)
                    .fixedSize(horizontal: false, vertical: true)  // Fix vertical size to prevent layout changes
                    
                    Spacer()
                    
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
                .animation(.easeInOut, value: audioRecorder.isRecording)
                .animation(.easeInOut, value: audioRecorder.isPlaying)
            }
            .onAppear {
                viewSize = geo.size
            }
            .onChange(of: geo.size) { _, newSize in
                viewSize = newSize
            }
            .onDisappear {
                stopBackgroundUpdates()
            }
        }
    }
    
    // Start recording and background painting
    private func startRecording() {
        // Start audio recording
        audioRecorder.startRecording()
        
        // Start the background painting with a clean canvas
        backgroundPainter.startPainting()
        
        // Start a timer to update the background
        startBackgroundUpdates()
        
        // Add animation for background transition
        withAnimation(.easeInOut(duration: 0.5)) {
            // Any additional animations when starting recording
        }
    }
    
    // Stop recording but preserve the background painting
    private func stopRecording() {
        // Stop audio recording
        audioRecorder.stopRecording()
        
        // Stop adding new elements to the background but keep what's there
        backgroundPainter.stopPainting()
        
        // Stop the background update timer
        stopBackgroundUpdates()
        
        // Add animation for background transition
        withAnimation(.easeInOut(duration: 0.5)) {
            // Any additional animations when stopping recording
        }
    }
    
    // Start the timer that updates the background painting
    private func startBackgroundUpdates() {
        // Cancel any existing timer
        stopBackgroundUpdates()
        
        // Create a new timer that updates the background painting
        // Use a slightly slower interval (0.15s) to add elements more gradually
        backgroundUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            updateBackgroundPainting()
        }
    }
    
    // Stop the background update timer
    private func stopBackgroundUpdates() {
        backgroundUpdateTimer?.invalidate()
        backgroundUpdateTimer = nil
    }
    
    // Update the background painting based on audio data
    private func updateBackgroundPainting() {
        guard audioRecorder.isRecording else { return }
        
        // Only update with significant audio to prevent noise from causing unwanted painting
        if audioRecorder.audioLevel > 0.1 {
            // Update the background painting with current audio data
            backgroundPainter.update(
                frequency: audioRecorder.dominantFrequency,
                level: audioRecorder.audioLevel,
                color: audioRecorder.frequencyColor,
                in: viewSize
            )
        }
    }
}

#Preview {
    ContentView()
}