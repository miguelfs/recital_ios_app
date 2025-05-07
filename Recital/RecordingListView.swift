import SwiftUI
import AVFoundation

struct RecordingListView: View {
    @ObservedObject var recordingManager: RecordingManager
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode: EditMode = .inactive
    @State private var showingRenameDialog = false
    @State private var recordingToRename: Recording?
    @State private var newName = ""
    
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
        
        return HStack {
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