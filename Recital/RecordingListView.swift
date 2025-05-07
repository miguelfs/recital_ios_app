import SwiftUI
import AVFoundation

struct RecordingListView: View {
    @ObservedObject var recordingManager: RecordingManager
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode: EditMode = .inactive
    @State private var showingRenameDialog = false
    @State private var recordingToRename: Recording?
    @State private var newName = ""
    @State private var expandedRecordingId: String? = nil
    
    // Playback progress is now handled by RecordingManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current playing bar at top (if any)
                if let currentPlaying = recordingManager.currentlyPlaying {
                    playbackBar(for: currentPlaying)
                }
                
                List {
                    ForEach(recordingManager.recordings) { recording in
                        recordingRow(for: recording)
                    }
                    .onDelete(perform: deleteRecordings)
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .environment(\.editMode, $editMode)
            .alert("Rename Recording", isPresented: $showingRenameDialog) {
                TextField("New name", text: $newName)
                
                Button("Cancel", role: .cancel) {
                    recordingToRename = nil
                    newName = ""
                }
                
                Button("Save") {
                    if let recording = recordingToRename {
                        recordingManager.renameRecording(recording, newName: newName)
                    }
                    recordingToRename = nil
                    newName = ""
                }
            }
            // No need to clean up timer anymore as it's managed by RecordingManager
        }
    }
    
    private func recordingRow(for recording: Recording) -> some View {
        let isCurrentlyPlaying = recordingManager.currentlyPlaying?.id == recording.id && recordingManager.isPlaying
        let isExpanded = expandedRecordingId == recording.id
        
        return VStack(spacing: 0) {
            HStack {
                // Play/Pause button
                Button(action: {
                    if isCurrentlyPlaying {
                        recordingManager.stopPlayback()
                    } else {
                        recordingManager.startPlayback(recording: recording)
                    }
                }) {
                    Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isCurrentlyPlaying ? .red : .green)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(recording.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Transcription indicator - only show if we have a transcription
                if let transcription = recording.transcription, !transcription.isEmpty {
                    Button(action: {
                        withAnimation {
                            expandedRecordingId = isExpanded ? nil : recording.id
                        }
                    }) {
                        Image(systemName: "captions.bubble\(isExpanded ? ".fill" : "")")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                if editMode == .active {
                    Button(action: {
                        recordingToRename = recording
                        newName = recording.name
                        showingRenameDialog = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if editMode == .active {
                    recordingToRename = recording
                    newName = recording.name
                    showingRenameDialog = true
                } else {
                    if isCurrentlyPlaying {
                        recordingManager.stopPlayback()
                    } else {
                        recordingManager.startPlayback(recording: recording)
                    }
                }
            }
            
            // Transcription section - only show if expanded
            if isExpanded, let _ = recording.transcriptionText, !recording.transcriptionText!.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcription:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Only play the recording if the current transcription isn't shown elsewhere
                    if recordingManager.isPlaying && recordingManager.currentlyPlaying?.id == recording.id {
                        // Show with word timestamps if playing
                        TimestampedTranscriptionView(recordingManager: recordingManager)
                            .font(.system(size: 14))
                            .frame(height: 80)
                    } else {
                        // Show plain text if not playing
                        ScrollView {
                            Text(recording.transcriptionText!)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        .frame(height: 80)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
            
            // If no transcription is available but we're playing this recording
            if isExpanded && (recording.transcription == nil || recording.transcription!.isEmpty) && isCurrentlyPlaying {
                VStack(alignment: .leading, spacing: 4) {
                    if recordingManager.isTranscribing {
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        Text("No transcription available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Generate Transcription") {
                            recordingManager.transcribeRecording(recording)
                        }
                        .font(.caption)
                        .padding(.top, 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }
    
    private func playbackBar(for recording: Recording) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    if recordingManager.isPlaying {
                        recordingManager.stopPlayback()
                    } else {
                        recordingManager.startPlayback(recording: recording)
                    }
                }) {
                    Image(systemName: recordingManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.red.opacity(0.9)))
                }
                .buttonStyle(BorderlessButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Now Playing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(recording.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Format time as MM:SS
                Text(formatTime(recordingManager.playbackProgress))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    + Text(" / ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    + Text(formatTime(recordingManager.playbackDuration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(0, CGFloat(recordingManager.playbackProgress / recordingManager.playbackDuration) * geometry.size.width), height: 4)
                }
            }
            .frame(height: 4)
            
            // Show transcription if available
            if !recordingManager.currentTranscription.isEmpty {
                // Use our timestamped transcription view that highlights the current word
                TimestampedTranscriptionView(recordingManager: recordingManager)
                    .font(.caption)
                    .frame(height: 60)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            recordingManager.deleteRecording(recordingManager.recordings[index])
        }
    }
    
    // MARK: - Playback Progress Tracking
    
    // Progress tracking is now handled by RecordingManager
    
    private func formatTime(_ timeInSeconds: Double) -> String {
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
struct RecordingListView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingListView(recordingManager: RecordingManager())
    }
}