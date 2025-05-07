import Foundation
import AVFoundation
import Speech

/*
IMPORTANT: This app requires privacy permissions to work properly.
You must add the following to your Info.plist:

<key>NSSpeechRecognitionUsageDescription</key>
<string>Recital needs speech recognition to transcribe your audio recordings</string>

<key>NSMicrophoneUsageDescription</key>
<string>Recital needs microphone access to record audio</string>
*/

// This service handles transcription of audio recordings
class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    @Published var liveTranscription = ""
    @Published var permissionStatus = "Unknown" // Track permission status
    
    // Transcription error types
    enum TranscriptionError: Error {
        case audioEngineFailed
        case noRecognitionAvailable
        case notAuthorized
        case audioSessionFailed
        case fileTooLong
        case fileNotFound
        case fileFormatNotSupported
        case permissionsNotInInfoPlist
    }
    
    // For storing transcriptions
    private let transcriptionCacheKey = "com.recital.transcriptions"
    private var transcriptionCache: [String: String] = [:]
    
    // Speech recognition components
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var hasPermission = false
    
    init() {
        loadTranscriptionCache()
        checkPermissions() // Check permissions instead of requesting immediately
    }
    
    // Check if permissions are properly set up
    private func checkPermissions() {
        // Get the main bundle's info dictionary
        if let infoDict = Bundle.main.infoDictionary {
            // Check if the required permission keys exist
            let hasSpeechKey = infoDict["NSSpeechRecognitionUsageDescription"] != nil
            let hasMicKey = infoDict["NSMicrophoneUsageDescription"] != nil
            
            if !hasSpeechKey {
                permissionStatus = "Missing speech recognition permission in Info.plist"
                print("WARNING: NSSpeechRecognitionUsageDescription is missing from Info.plist")
            }
            
            if !hasMicKey {
                permissionStatus = "Missing microphone permission in Info.plist"
                print("WARNING: NSMicrophoneUsageDescription is missing from Info.plist")
            }
            
            // Only request authorization if the keys are present
            if hasSpeechKey && hasMicKey {
                requestSpeechAuthorization()
            }
        }
    }
    
    // Request permission to use speech recognition
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                    self.hasPermission = true
                case .denied:
                    print("Speech recognition authorization denied")
                    self.permissionStatus = "Speech recognition denied"
                case .restricted:
                    print("Speech recognition restricted on this device")
                    self.permissionStatus = "Speech recognition restricted"
                case .notDetermined:
                    print("Speech recognition not yet authorized")
                    self.permissionStatus = "Waiting for permission"
                @unknown default:
                    print("Unknown authorization status")
                    self.permissionStatus = "Unknown status"
                }
            }
        }
    }
    
    // Get cached transcription if available
    func getTranscription(for recordingId: String) -> String? {
        return transcriptionCache[recordingId]
    }
    
    // Transcribe an existing audio file
    func transcribeAudioFile(url: URL, recordingId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Check if we already have a transcription
        if let existingTranscription = transcriptionCache[recordingId] {
            transcriptionText = existingTranscription
            completion(.success(existingTranscription))
            return
        }
        
        // Check if the required Info.plist keys are present
        guard Bundle.main.infoDictionary?["NSSpeechRecognitionUsageDescription"] != nil else {
            transcriptionText = "Cannot transcribe - permission not configured in app"
            print("ERROR: NSSpeechRecognitionUsageDescription is missing from Info.plist")
            completion(.failure(TranscriptionError.permissionsNotInInfoPlist))
            return
        }
        
        // Make sure speech recognition is available
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            if authStatus == .notDetermined {
                transcriptionText = "Requesting permission..."
                
                // Request authorization and try again
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    guard let self = self else { return }
                    
                    if status == .authorized {
                        // Try again after authorization
                        DispatchQueue.main.async {
                            self.transcribeAudioFile(url: url, recordingId: recordingId, completion: completion)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.transcriptionText = "Speech recognition not authorized"
                            completion(.failure(TranscriptionError.notAuthorized))
                        }
                    }
                }
                return
            } else {
                transcriptionText = "Speech recognition not authorized"
                completion(.failure(TranscriptionError.notAuthorized))
                return
            }
        }
        
        // Create the recognition request
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        recognitionRequest.shouldReportPartialResults = true
        
        // Start the recognition task
        isTranscribing = true
        transcriptionText = "Transcribing..."
        
        speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isTranscribing = false
                
                // Handle specific errors more gracefully
                let nserror = error as NSError
                // Check if it's a cancellation error (which is actually fine if we already have text)
                if nserror.domain == "kAFAssistantErrorDomain" && nserror.code == 1 {
                    // This is just a cancellation - if we have some text already, use it
                    if !self.transcriptionText.isEmpty && self.transcriptionText != "Transcribing..." {
                        // We have partial results, let's use them instead of failing
                        let partialText = self.transcriptionText
                        self.transcriptionCache[recordingId] = partialText
                        self.saveTranscriptionCache()
                        completion(.success(partialText))
                        return
                    }
                }
                
                // For other errors, show a cleaner message
                self.transcriptionText = "Unable to transcribe audio"
                print("Transcription error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let result = result else {
                self.isTranscribing = false
                self.transcriptionText = "No result from transcription"
                completion(.failure(TranscriptionError.noRecognitionAvailable))
                return
            }
            
            // Get the transcription text
            let transcription = result.bestTranscription.formattedString
            
            // Update the transcription text
            DispatchQueue.main.async {
                self.transcriptionText = transcription
                
                // If this is the final result, save it to the cache
                if result.isFinal {
                    self.isTranscribing = false
                    self.transcriptionCache[recordingId] = transcription
                    self.saveTranscriptionCache()
                    completion(.success(transcription))
                }
            }
        }
    }
    
    // Start live transcription for the currently recording audio
    func startLiveTranscription() {
        // Check if the required Info.plist keys are present
        guard Bundle.main.infoDictionary?["NSSpeechRecognitionUsageDescription"] != nil else {
            print("ERROR: NSSpeechRecognitionUsageDescription is missing from Info.plist")
            liveTranscription = "Cannot transcribe - permission not configured in app"
            return
        }
        
        // Make sure speech recognition is available
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("Speech recognition not authorized")
            if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                liveTranscription = "Requesting permission..."
                requestSpeechAuthorization()
            } else {
                liveTranscription = "Speech recognition not authorized"
            }
            return
        }
        
        // Stop any existing recognition task
        stopLiveTranscription()
        
        // Start a new audio engine
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            print("Could not create audio engine")
            return
        }
        
        // Create the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Could not create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure the audio session for the recognition
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Could not configure audio session: \(error.localizedDescription)")
            liveTranscription = "Error setting up audio session"
            return
        }
        
        // Get the input node from the audio engine
        let inputNode = audioEngine.inputNode
        
        // Create a recording format that matches the input node's format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install a tap on the input node to get the audio data
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start the audio engine
        do {
            try audioEngine.start()
            isTranscribing = true
            liveTranscription = "Listening..."
        } catch {
            print("Could not start audio engine: \(error.localizedDescription)")
            liveTranscription = "Error starting audio capture"
            isTranscribing = false
            return
        }
        
        // Start the recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Recognition task error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.liveTranscription = "Error: \(error.localizedDescription)"
                }
                self.stopLiveTranscription()
                return
            }
            
            guard let result = result else {
                print("No result from recognition task")
                return
            }
            
            // Get the transcription text
            let transcription = result.bestTranscription.formattedString
            
            // Update the live transcription
            DispatchQueue.main.async {
                self.liveTranscription = transcription
            }
            
            // If this is the final result, stop the recognition task
            if result.isFinal {
                self.stopLiveTranscription()
            }
        }
    }
    
    // Stop the live transcription
    func stopLiveTranscription() {
        // Save the current transcription text before stopping
        let currentText = liveTranscription
        
        // If we have meaningful transcription text, save it
        if !currentText.isEmpty && currentText != "Listening..." {
            // We'll keep this for later use when saving recordings
            // Don't clear liveTranscription so it can be saved with the recording
        }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Instead of canceling, try to finish the task more gracefully
        if let task = recognitionTask {
            // Only cancel if we don't have meaningful text yet
            if liveTranscription.isEmpty || liveTranscription == "Listening..." {
                task.cancel()
            } else {
                // Otherwise, let it finish by itself
                // The task will complete on its own once the audio buffer is processed
            }
        }
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isTranscribing = false
    }
    
    // Save transcriptions to cache
    func saveTranscription(for recordingId: String, text: String) {
        transcriptionCache[recordingId] = text
        saveTranscriptionCache()
    }
    
    // Load transcriptions from cache
    private func loadTranscriptionCache() {
        if let data = UserDefaults.standard.data(forKey: transcriptionCacheKey) {
            do {
                let cache = try JSONDecoder().decode([String: String].self, from: data)
                transcriptionCache = cache
            } catch {
                print("Error loading transcription cache: \(error.localizedDescription)")
            }
        }
    }
    
    // Save transcriptions to cache
    private func saveTranscriptionCache() {
        do {
            let data = try JSONEncoder().encode(transcriptionCache)
            UserDefaults.standard.set(data, forKey: transcriptionCacheKey)
        } catch {
            print("Error saving transcription cache: \(error.localizedDescription)")
        }
    }
}