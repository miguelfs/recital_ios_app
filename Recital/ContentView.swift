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
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 250, height: 250)
                
                // Audio visualization placeholder (can be replaced with actual visualization)
                if audioRecorder.isRecording {
                    Circle()
                        .stroke(Color.red, lineWidth: 5)
                        .frame(width: 240, height: 240)
                }
                
                // Recording button
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(audioRecorder.isRecording ? .red : .blue)
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
