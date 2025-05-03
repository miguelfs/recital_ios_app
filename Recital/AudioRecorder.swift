import Foundation
import AVFoundation
import SwiftUI

class AudioRecorder: NSObject, ObservableObject {
    // MARK: - Properties
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var audioURL: URL?
    @Published var audioLevel: CGFloat = 0.0 // Audio level for visualization
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var levelUpdateTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recording Functions
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true // Enable metering for level visualization
            audioRecorder?.record()
            isRecording = true
            audioURL = audioFilename
            
            // Set up audio engine for buffer access
            startAudioEngine()
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // Stop audio engine
        stopAudioEngine()
    }
    
    // MARK: - Audio Engine for Buffer Access
    private func startAudioEngine() {
        audioBuffers.removeAll()
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            
            // Start a timer to update the audio level UI
            self.levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.updateAudioLevels()
            }
        } catch {
            print("Could not start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func stopAudioEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        // Stop the level update timer
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        
        // Reset audio level
        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Store the buffer for later use
        let bufferCopy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)
        bufferCopy?.frameLength = buffer.frameLength
        
        // Copy the sample data
        if let src = buffer.floatChannelData?[0], let dst = bufferCopy?.floatChannelData?[0] {
            memcpy(dst, src, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }
        
        if let bufferCopy = bufferCopy {
            audioBuffers.append(bufferCopy)
        }
        
        // Audio level calculation will be handled in updateAudioLevels()
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        
        // Get the peak power from the recorder
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Convert dB to linear scale (dB is logarithmic)
        // Normalize from -160dB (lowest) to 0dB (highest)
        // -160dB to -50dB is essentially silence, so we'll adjust our scale
        let minDb: Float = -50.0
        let normalizedValue = max(0.0, (averagePower - minDb) / abs(minDb))
        
        // Add a bit more dynamics to make visualization more responsive
        let scaledValue = pow(normalizedValue, 0.5) * 1.5
        
        // Update audio level on main thread
        DispatchQueue.main.async {
            // Apply smoothing to make animation more natural
            let smoothing: CGFloat = 0.2
            self.audioLevel = self.audioLevel * (1 - smoothing) + CGFloat(scaledValue) * smoothing
        }
    }
    
    // MARK: - Playback Functions
    func startPlayback() {
        guard let audioURL = audioURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Could not start playback: \(error.localizedDescription)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    // MARK: - Helpers
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Access to audio buffers for processing
    func getAudioBuffers() -> [AVAudioPCMBuffer] {
        return audioBuffers
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}