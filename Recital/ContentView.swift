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
            Text("Recital")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 250, height: 250)
                
                // Audio level visualization bubbles
                if audioRecorder.isRecording {
                    // Base pulse circle that's always visible
                    Circle()
                        .stroke(audioRecorder.frequencyColor.opacity(0.7), lineWidth: 3)
                        .frame(width: 240, height: 240)
                    
                    // Multiple animated circles based on audio level
                    ForEach(1...5, id: \.self) { index in
                        let delay = Double(index) / 10.0
                        
                        Circle()
                            .stroke(
                                audioRecorder.frequencyColor.opacity(0.7 - Double(index) * 0.1), 
                                lineWidth: 3
                            )
                            .frame(
                                width: 140 + (audioRecorder.audioLevel * 120) * CGFloat(index) / 3,
                                height: 140 + (audioRecorder.audioLevel * 120) * CGFloat(index) / 3
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0).delay(delay), value: audioRecorder.audioLevel)
                            .animation(.easeInOut(duration: 0.3).delay(delay), value: audioRecorder.frequencyColor)
                    }
                    
                    // Debug info for frequency (optional - can be removed)
                    Text("Freq: \(Int(audioRecorder.dominantFrequency)) Hz")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .opacity(0.7)
                        .offset(y: -120)
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
                        // Button background
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        
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
            
            // Playback button
            if audioRecorder.audioURL != nil {
                Button(action: {
                    if audioRecorder.isPlaying {
                        audioRecorder.stopPlayback()
                    } else {
                        audioRecorder.startPlayback()
                    }
                }) {
                    HStack {
                        Image(systemName: audioRecorder.isPlaying ? "stop.fill" : "play.fill")
                            .foregroundColor(audioRecorder.isPlaying ? .red : .green)
                        Text(audioRecorder.isPlaying ? "Stop Playback" : "Play Recording")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(audioRecorder.isRecording)
            }
            
            // Debug info
            VStack(alignment: .leading, spacing: 5) {
                Text("Status: \(audioRecorder.isRecording ? "Recording" : audioRecorder.isPlaying ? "Playing" : "Idle")")
                if let url = audioRecorder.audioURL {
                    Text("Recording saved at: \(url.lastPathComponent)")
                        .font(.caption)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
