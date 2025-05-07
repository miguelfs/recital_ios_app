import Foundation
import SwiftUI
import AVFoundation

struct Recording: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var date: Date
    var audioUrl: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("\(id).m4a")
    }
    var backgroundData: Data? // Serialized background data
    
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
    @Published var playbackProgress: Double = 0
    @Published var playbackDuration: Double = 1
    
    var audioPlayer: AVAudioPlayer?
    private weak var backgroundPainter: BackgroundPainter?
    private var playbackTimer: Timer?
    
    init(backgroundPainter: BackgroundPainter? = nil) {
        self.backgroundPainter = backgroundPainter
        super.init()
        loadRecordings()
    }
    
    func setBackgroundPainter(_ painter: BackgroundPainter) {
        self.backgroundPainter = painter
    }
    
    // MARK: - Recording Management
    
    func saveRecording(name: String, backgroundData: Data?) {
        let recording = Recording(
            name: name,
            date: Date(),
            backgroundData: backgroundData
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
            }
        } catch {
            print("Error saving recording: \(error.localizedDescription)")
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
        
        setupAudioSession()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.audioUrl)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            // Update state
            currentlyPlaying = recording
            isPlaying = true
            
            // Update playback duration
            playbackDuration = audioPlayer?.duration ?? 1.0
            playbackProgress = 0
            
            // Start a timer to update playback progress
            startProgressTimer()
            
            // Load the background if available
            if let backgroundPainter = backgroundPainter {
                backgroundPainter.loadBackground(from: recording.backgroundData)
            }
        } catch {
            print("Error starting playback: \(error.localizedDescription)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        stopProgressTimer()
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