//
//  ContentView.swift
//  Recital
//
//  Created by Miguel Sousa on 02/05/25.
//

import SwiftUI
import AVFoundation

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
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0).delay(delay), value: audioRecorder.audioLevel)
                            .animation(.easeInOut(duration: 0.3).delay(delay), value: audioRecorder.frequencyColor)
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
                        // Button background with gradient
                        Circle()
                            .fill(
                                audioRecorder.isRecording 
                                ? LinearGradient(colors: [.red, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.blue, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 110, height: 110)
                            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                        
                        // Button icon
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                }
                .disabled(audioRecorder.isPlaying)
            }
            .padding()
            .frame(height: 350)
            
            // Playback button with improved styling
            if audioRecorder.audioURL != nil {
                Button(action: {
                    if audioRecorder.isPlaying {
                        audioRecorder.stopPlayback()
                    } else {
                        audioRecorder.startPlayback()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: audioRecorder.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(audioRecorder.isPlaying ? .red : .green)
                        
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
                .disabled(audioRecorder.isRecording)
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
