import AVFoundation
import Accelerate
import Foundation
import SwiftUI


class AudioRecorder: NSObject, ObservableObject {
    // MARK: - Static Configuration Values
    private static let sampleRate: Float = 48000.0
    private static let fftSize: Int = 1024
    private static let numberOfChannels: Int = 1
    
    // Audio buffer and timing constants
    private static let audioBufferSize: UInt32 = 1024
    private static let levelUpdateInterval: TimeInterval = 0.01
    
    // Frequency ranges for color mapping
    private static let lowFrequencyRange: ClosedRange<Float> = 20...80  // Bass
    private static let midFrequencyRange: ClosedRange<Float> = 150...400  // Mids
    private static let highFrequencyRange: ClosedRange<Float> = 400...20000  // Highs
    

    // MARK: - Properties
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var audioURL: URL
    @Published var audioLevel: CGFloat = 0.0  // Audio level for visualization
    @Published var dominantFrequency: Float = 0.0  // Dominant frequency from FFT
    @Published var frequencyColor: Color = .red  // Color based on frequency
    
    // Recording summary statistics
    private var frequencySum: Float = 0.0
    private var frequencySamples: Int = 0
    private var maxAudioLevel: CGFloat = 0.0
    
    // Public computed properties for summary data
    var averageFrequency: Float {
        return frequencySamples > 0 ? frequencySum / Float(frequencySamples) : 0
    }
    
    var maxLevel: CGFloat {
        return maxAudioLevel
    }

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var levelUpdateTimer: Timer?

    // FFT related properties
    private let fftSetup: FFTSetup?
    private let fftSize: Int
    private let log2n: UInt
    private var frequencyBins: [Float] = []

    // Frequency ranges for color mapping (instance references to static values)
    private let lowFrequencyRange: ClosedRange<Float>
    private let midFrequencyRange: ClosedRange<Float>
    private let highFrequencyRange: ClosedRange<Float>

    override init() {
        // Initialize FFT properties from static values
        self.fftSize = AudioRecorder.fftSize
        let log2n = UInt(log2(Double(AudioRecorder.fftSize)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        // Get audio URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsDirectory.appendingPathComponent("recording.m4a")
        
        // Copy static frequency ranges to instance properties
        self.lowFrequencyRange = AudioRecorder.lowFrequencyRange
        self.midFrequencyRange = AudioRecorder.midFrequencyRange
        self.highFrequencyRange = AudioRecorder.highFrequencyRange
        
        // Initialize properties before super.init
        self.log2n = log2n
        self.fftSetup = fftSetup
        self.audioURL = url
        
        super.init()
        
        // Now we can safely use self
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Int(AudioRecorder.sampleRate),
            AVNumberOfChannelsKey: AudioRecorder.numberOfChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        
        //TODO: wrap the try below.
        do {
            self.audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true  // Enable metering for level visualization
        } catch {
            print("Failed to initialize audio recorder: \(error.localizedDescription)")
        }
        
        // Initialize audio session immediately to reduce first-record delay
        setupAudioSession()
        setupFrequencyBins()
        
    }
    

    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    private func setupFrequencyBins() {
        // Calculate frequency bins based on sample rate
        frequencyBins = (0..<fftSize / 2).map { Float($0) * AudioRecorder.sampleRate / Float(fftSize) }
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Set category to playAndRecord with options to use the main speaker for playback
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default, 
                                        options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording Functions
    func startRecording() {
        // Haptic feedback moved to the UI button press
        
        // Reset recording statistics
        frequencySum = 0.0
        frequencySamples = 0
        maxAudioLevel = 0.0

        do {
          //  audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true

            // Set up audio engine for buffer access
            startAudioEngine()
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        // Provide haptic feedback when stopping recording
        provideTactileFeedback(.medium)

        audioRecorder?.stop()
        isRecording = false

        // Stop audio engine
        stopAudioEngine()
    }

    // MARK: - Haptic Feedback

    /// Provides tactile feedback with specified impact style
    private func provideTactileFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Audio Engine for Buffer Access
    private func startAudioEngine() {
        audioBuffers.removeAll()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: AudioRecorder.audioBufferSize, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()

            // Start a timer to update the audio level UI
            self.levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: AudioRecorder.levelUpdateInterval, repeats: true) {
                [weak self] _ in
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
        let bufferCopy = AVAudioPCMBuffer(
            pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)
        bufferCopy?.frameLength = buffer.frameLength

        // Copy the sample data
        if let src = buffer.floatChannelData?[0], let dst = bufferCopy?.floatChannelData?[0] {
            memcpy(dst, src, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }

        if let bufferCopy = bufferCopy {
            audioBuffers.append(bufferCopy)

            // Perform FFT on the buffer data
            if buffer.frameLength >= UInt32(fftSize) {
                performFFT(buffer: buffer)
            }
        }

        // Audio level calculation will be handled in updateAudioLevels()
    }

    private func performFFT(buffer: AVAudioPCMBuffer) {
        guard let fftSetup = fftSetup,
            let channelData = buffer.floatChannelData?[0]
        else { return }

        // Prepare input and output buffers for FFT
        let inputCount = fftSize
        var realIn = [Float](repeating: 0, count: inputCount)
        var realOut = [Float](repeating: 0, count: inputCount / 2)
        var imagOut = [Float](repeating: 0, count: inputCount / 2)

        // Copy audio data to input buffer using vectorized window function
        let bufferLength = min(Int(buffer.frameLength), inputCount)

        // Create Hann window coefficients using vDSP
        var window = [Float](repeating: 0, count: bufferLength)
        vDSP_hann_window(&window, vDSP_Length(bufferLength), Int32(0))

        // Apply window using vector multiply for better performance
        vDSP_vmul(channelData, 1, window, 1, &realIn, 1, vDSP_Length(bufferLength))

        // Create complex input
        var splitComplex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)

        // Pack real data into complex format
        realIn.withUnsafeBytes { rawBufferPointer in
            let typePtr = rawBufferPointer.bindMemory(to: DSPComplex.self)
            if let baseAddress = typePtr.baseAddress {
                vDSP_ctoz(baseAddress, 2, &splitComplex, 1, vDSP_Length(inputCount / 2))
            }
        }

        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, self.log2n, FFTDirection(kFFTDirection_Forward))

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: inputCount / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, UInt(inputCount / 2))

        // Normalize magnitudes
        for i in 0..<magnitudes.count {
            magnitudes[i] = sqrtf(magnitudes[i]) / Float(fftSize)
        }

        // Find peak frequency
        if let maxIndex = magnitudes[1..<(inputCount / 2)].enumerated().max(by: {
            $0.element < $1.element
        })?.offset {
            let peakFrequency = frequencyBins[maxIndex + 1]  // +1 to account for the 1..< range above

            // Update dominant frequency (with smoothing)
            let smoothingFactor: Float = 0.2
            DispatchQueue.main.async {
                let newFrequency = self.dominantFrequency * (1 - smoothingFactor) + peakFrequency * smoothingFactor
                self.dominantFrequency = newFrequency
                
                // Track frequency for summary statistics
                if self.isRecording && newFrequency > 20 { // Only track meaningful frequencies
                    self.frequencySum += newFrequency
                    self.frequencySamples += 1
                }
                
                self.updateFrequencyColor()
            }
        }
    }

    private func updateFrequencyColor() {
        // Map frequency ranges to colors
        if lowFrequencyRange.contains(dominantFrequency) {
            // Bass frequency - red to orange range
            let normalizedValue = normalize(
                dominantFrequency,
                fromRange: lowFrequencyRange,
                toRange: 0...1)
            frequencyColor = Color(
                hue: Double(0.0 + normalizedValue * 0.1),
                saturation: 1.0,
                brightness: 0.9)
        } else if midFrequencyRange.contains(dominantFrequency) {
            // Mid frequency - yellow to green range
            let normalizedValue = normalize(
                dominantFrequency,
                fromRange: midFrequencyRange,
                toRange: 0...1)
            frequencyColor = Color(
                hue: Double(0.1 + normalizedValue * 0.25),
                saturation: 0.9,
                brightness: 0.9)
        } else if highFrequencyRange.contains(dominantFrequency) {
            // High frequency - blue to purple range
            let normalizedValue = normalize(
                dominantFrequency,
                fromRange: highFrequencyRange,
                toRange: 0...1)
            frequencyColor = Color(
                hue: Double(0.5 + normalizedValue * 0.3),
                saturation: 0.8,
                brightness: 0.9)
        } else {
            // Default color for frequencies outside the expected range
            frequencyColor = .red
        }
    }

    private func normalize(
        _ value: Float, fromRange: ClosedRange<Float>, toRange: ClosedRange<Float>
    ) -> Float {
        let normalizedValue =
            (value - fromRange.lowerBound) / (fromRange.upperBound - fromRange.lowerBound)
        return normalizedValue * (toRange.upperBound - toRange.lowerBound) + toRange.lowerBound
    }

    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }

        recorder.updateMeters()

        // Get the average power from the recorder
        let averagePower = recorder.averagePower(forChannel: 0)
        // Using _ to explicitly ignore peakPower since we're not using it
        _ = recorder.peakPower(forChannel: 0)

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
            let newLevel = self.audioLevel * (1 - smoothing) + CGFloat(scaledValue) * smoothing
            self.audioLevel = newLevel
            
            // Track max level for summary statistics
            if self.isRecording && newLevel > self.maxAudioLevel {
                self.maxAudioLevel = newLevel
            }
        }
    }

    // MARK: - Playback Functions
    func startPlayback() {
        // Lighter feedback for playback operations
        provideTactileFeedback(.light)

        do {
            // Ensure audio session is configured to use the main speaker
            // The .defaultToSpeaker option is only valid with .playAndRecord category
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            
            // Force output to speaker
            do {
                try audioSession.overrideOutputAudioPort(.speaker)
            } catch {
                print("Could not override audio port to speaker: \(error.localizedDescription)")
            }
            
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Could not start playback: \(error.localizedDescription)")
        }
    }

    func stopPlayback() {
        // Lighter feedback for playback operations
        provideTactileFeedback(.light)

        audioPlayer?.stop()
        isPlaying = false
        
        // Restore audio session to playAndRecord for the next recording
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default, 
                                        options: [.defaultToSpeaker, .allowBluetooth])
        } catch {
            print("Could not restore audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers
    // Access to audio buffers for processing
    func getAudioBuffers() -> [AVAudioPCMBuffer] {
        return audioBuffers
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false

        // Provide success feedback when playback completes naturally
        if flag {
            // Use a success feedback pattern for completion
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
