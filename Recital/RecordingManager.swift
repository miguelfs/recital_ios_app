import Foundation
import SwiftUI
import AVFoundation
import Combine

struct Recording: Identifiable, Codable {
    var id: String
    var name: String
    var date: Date
    var audioUrl: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("\(id).m4a")
    }
    var backgroundData: Data? // Serialized background data
    var transcription: String? // Transcription text
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

class RecordingManager: NSObject, ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var currentlyPlaying: Recording?
    @Published var isPlaying = false
    @Published var isPreviewing = false
    @Published var playbackProgress: Double = 0
    @Published var playbackDuration: Double = 1
    @Published var previewedBrushId: String?  // ID of the brush being previewed
    @Published var currentTranscription: String = ""
    @Published var isTranscribing: Bool = false
    
    var audioPlayer: AVAudioPlayer?
    private weak var backgroundPainter: BackgroundPainter?
    private var playbackTimer: Timer?
    private var previewTimer: Timer?  // Timer to auto-stop preview
    
    // Transcription service
    let transcriptionService = TranscriptionService()
    
    init(backgroundPainter: BackgroundPainter? = nil) {
        self.backgroundPainter = backgroundPainter
        super.init()
        loadRecordings()
        
        // Subscribe to transcription service updates
        transcriptionService.$transcriptionText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.currentTranscription = text
            }
            .store(in: &cancellables)
        
        transcriptionService.$isTranscribing
            .receive(on: RunLoop.main)
            .sink { [weak self] isTranscribing in
                self?.isTranscribing = isTranscribing
            }
            .store(in: &cancellables)
    }
    
    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    func setBackgroundPainter(_ painter: BackgroundPainter) {
        self.backgroundPainter = painter
    }
    
    // MARK: - Recording Management
    
    func saveRecording(name: String, backgroundData: Data?, recordingId: String) {
        // Get any transcription from live transcription
        var initialTranscription: String? = nil
        
        let liveText = transcriptionService.liveTranscription
        if !liveText.isEmpty && liveText != "Listening..." && !liveText.contains("Error:") {
            initialTranscription = liveText
        }
        
        let recording = Recording(
            id: recordingId,  // Use the provided ID
            name: name,
            date: Date(),
            backgroundData: backgroundData,
            transcription: initialTranscription
        )
        
        // Copy the temporary recording to a permanent location
        let tempRecordingUrl = getTempRecordingUrl()
        let destinationUrl = recording.audioUrl
        
        do {
            if FileManager.default.fileExists(atPath: tempRecordingUrl.path) {
                // If a file already exists at the destination, remove it first
                if FileManager.default.fileExists(atPath: destinationUrl.path) {
                    try FileManager.default.removeItem(at: destinationUrl)
                }
                
                // Copy the recording file
                try FileManager.default.copyItem(at: tempRecordingUrl, to: destinationUrl)
                
                // Add to recordings list and save metadata
                recordings.append(recording)
                saveRecordingsMetadata()
                
                // Start transcription in the background if we don't have one already
                if initialTranscription == nil {
                    transcribeRecording(recording)
                }
            }
        } catch {
            print("Error saving recording: \(error.localizedDescription)")
        }
    }
    
    // Start transcription for a recording
    func transcribeRecording(_ recording: Recording) {
        // Skip if we already have a transcription
        if recording.transcription != nil && !recording.transcription!.isEmpty {
            return
        }
        
        // Start the transcription
        transcriptionService.transcribeAudioFile(url: recording.audioUrl, recordingId: recording.id) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let transcription):
                // Update the recording with the transcription
                if let index = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                    DispatchQueue.main.async {
                        self.recordings[index].transcription = transcription
                        self.saveRecordingsMetadata()
                        
                        // Update current transcription if this is the currently playing recording
                        if self.currentlyPlaying?.id == recording.id {
                            self.currentTranscription = transcription
                        }
                    }
                }
                
            case .failure(let error):
                print("Transcription failed: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        // Stop playback if this is the currently playing recording
        if currentlyPlaying?.id == recording.id {
            stopPlayback()
        }
        
        // Remove the audio file
        do {
            if FileManager.default.fileExists(atPath: recording.audioUrl.path) {
                try FileManager.default.removeItem(at: recording.audioUrl)
            }
        } catch {
            print("Error deleting recording file: \(error.localizedDescription)")
        }
        
        // Remove from recordings array
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings.remove(at: index)
            saveRecordingsMetadata()
        }
        
        // Remove the associated bubble from the background painter
        if let painter = backgroundPainter {
            // Remove bubbles that have this recording ID
            painter.removeBrushesWithRecordingId(recording.id)
        }
    }
    
    func renameRecording(_ recording: Recording, newName: String) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index].name = newName
            saveRecordingsMetadata()
        }
    }
    
    // MARK: - Playback
    
    func startPlayback(recording: Recording) {
        guard audioPlayer?.isPlaying != true else {
            stopPlayback()
            return
        }
        
        // Stop any preview that might be playing
        stopPreview()
        
        setupAudioSession()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.audioUrl)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            // Update state
            currentlyPlaying = recording
            isPlaying = true
            isPreviewing = false
            
            // Update playback duration
            playbackDuration = audioPlayer?.duration ?? 1.0
            playbackProgress = 0
            
            // Start a timer to update playback progress
            startProgressTimer()
            
            // Load the background if available
            if let backgroundPainter = backgroundPainter {
                backgroundPainter.loadBackground(from: recording.backgroundData)
            }
            
            // Set the current transcription
            if let transcription = recording.transcription {
                currentTranscription = transcription
            } else {
                // If no transcription yet, start transcription
                currentTranscription = "Transcribing..."
                transcribeRecording(recording)
            }
        } catch {
            print("Error starting playback: \(error.localizedDescription)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        isPreviewing = false
        previewedBrushId = nil
        stopProgressTimer()
        currentTranscription = ""
    }
    
    // MARK: - Preview Functions
    
    // Start preview playback for a specific bubble/brush
    func previewRecordingForBrush(withId recordingId: String) {
        // Stop any existing playback or preview
       stopPlayback()
       stopPreview()
        
        // Find the recording that matches this ID
        guard let recording = recordings.first(where: { $0.id == recordingId }) else {
            print("No recording found for ID: \(recordingId)")
            return
        }
        
        // Note: We no longer provide haptic feedback here because it's now provided
        // immediately when the bubble is pressed in the onPressingChanged callback
        
       setupAudioSession()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.audioUrl)
            audioPlayer?.delegate = self
            
            // Calculate a position more toward the middle of the recording
            let duration = audioPlayer?.duration ?? 0
            if duration > 1.0 {
                // If longer than 1 second, start 1/3 of the way through 
                let previewPoint = duration / 3.0
                audioPlayer?.currentTime = previewPoint
            }
            
            // Set up a fade in effect
            audioPlayer?.setVolume(0, fadeDuration: 0)
            audioPlayer?.play()
            audioPlayer?.setVolume(1, fadeDuration: 0.1) // Fade in over 0.5 seconds
            
            // Update state
            currentlyPlaying = recording
            isPreviewing = true
            isPlaying = false  // Not a full playback
            previewedBrushId = recordingId
            
            // Update progress tracking
            playbackDuration = duration
            playbackProgress = audioPlayer?.currentTime ?? 0
            startProgressTimer()
            
            // Set up a timer to automatically stop preview after a few seconds
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.stopPreview()
            }
        } catch {
            print("Error starting preview: \(error.localizedDescription)")
        }
    }
    
    func stopPreview() {
        // If we're previewing, fade out before stopping
        if isPreviewing, let player = audioPlayer {
            // Fade out over 0.5 seconds
            player.setVolume(0, fadeDuration: 0.5)
            
            // Schedule stopping after fade completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                player.stop()
                self.isPreviewing = false
                self.previewedBrushId = nil
                self.stopProgressTimer()
            }
        } else {
            // Just stop immediately if not previewing
            audioPlayer?.stop()
            isPreviewing = false
            previewedBrushId = nil
            stopProgressTimer()
        }
        
        // Cancel any pending preview timer
        previewTimer?.invalidate()
        previewTimer = nil
    }
    
    // MARK: - Playback Progress Tracking
    
    private func startProgressTimer() {
        // Cancel any existing timer
        stopProgressTimer()
        
        // Start a new timer
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.playbackProgress = player.currentTime
        }
    }
    
    private func stopProgressTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - Private Helper Methods
    
    private func getTempRecordingUrl() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("recording.m4a")
    }
    
    private func getMetadataUrl() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("recordings.json")
    }
    
    private func saveRecordingsMetadata() {
        do {
            let data = try JSONEncoder().encode(recordings)
            try data.write(to: getMetadataUrl(), options: .atomic)
        } catch {
            print("Error saving recordings metadata: \(error.localizedDescription)")
        }
    }
    
    private func loadRecordings() {
        let metadataUrl = getMetadataUrl()
        
        if FileManager.default.fileExists(atPath: metadataUrl.path) {
            do {
                let data = try Data(contentsOf: metadataUrl)
                recordings = try JSONDecoder().decode([Recording].self, from: data)
            } catch {
                print("Error loading recordings: \(error.localizedDescription)")
                recordings = []
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension RecordingManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopProgressTimer()
            
            // Provide success feedback when playback completes naturally
            if flag {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)
            }
        }
    }
}
