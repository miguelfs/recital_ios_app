import Foundation
import Speech

// Represents a single word with its timestamp in the transcription
struct TranscriptionWord: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var timestamp: TimeInterval // Start time of the word in seconds
    var duration: TimeInterval?  // Duration of the word in seconds (if available)
    
    var endTimestamp: TimeInterval {
        if let duration = duration {
            return timestamp + duration
        } else {
            // Estimate a reasonable end time if duration isn't available
            return timestamp + Double(text.count) * 0.1
        }
    }
    
    static func == (lhs: TranscriptionWord, rhs: TranscriptionWord) -> Bool {
        return lhs.id == rhs.id
    }
}

// Represents a complete transcription with all its words and timing information
struct TimestampedTranscription: Codable {
    var words: [TranscriptionWord]
    var fullText: String
    var duration: TimeInterval
    
    // Get the currently spoken word based on playback position
    func currentWordIndex(at position: TimeInterval) -> Int? {
        // Return the index of the word being spoken at the given position
        // Use a more robust approach that handles potential overlap or gaps

        // First check if position is before first word or after last word
        if words.isEmpty {
            return nil
        }
        
        if position < words.first!.timestamp {
            return 0 // Return first word if before any word
        }
        
        if position > words.last!.endTimestamp {
            return words.count - 1 // Return last word if after all words
        }
        
        // Find the exact word that contains this position
        for (index, word) in words.enumerated() {
            if position >= word.timestamp && position <= word.endTimestamp {
                return index
            }
        }
        
        // If we get here, the position is between words.
        // Find the closest word that occurs AFTER the current position.
        // This prevents highlighting words out of order.
        var nextWordIndex: Int? = nil
        var minDistance = Double.infinity
        
        for (index, word) in words.enumerated() {
            if word.timestamp > position {
                let distance = word.timestamp - position
                if distance < minDistance {
                    minDistance = distance
                    nextWordIndex = index
                }
            }
        }
        
        // If we found a word after the current position, use the previous word
        if let nextIndex = nextWordIndex {
            return max(0, nextIndex - 1)
        }
        
        // If we couldn't find a word after the position, we must be between the last word's
        // endTimestamp and some later position, so return the last word
        return words.count - 1
    }
    
    // For backward compatibility - create from plain text
    static func fromPlainText(_ text: String) -> TimestampedTranscription {
        // Create a basic transcription with estimated timestamps
        
        // Use a more realistic word timing model
        // Typical speaking rate: 120-150 words per minute
        // This means ~0.4-0.5 seconds per word on average
        
        let components = text.split(separator: " ")
        let totalWords = components.count
        
        // If text is empty, return empty transcription
        if totalWords == 0 {
            return TimestampedTranscription(
                words: [],
                fullText: text,
                duration: 0
            )
        }
        
        // Use a fixed average word duration for more stable timing
        let baseWordDuration = 0.4 // 400ms per word base duration
        
        var words: [TranscriptionWord] = []
        var currentTime: Double = 0.0
        
        // Add a small initial delay
        currentTime = 0.1
        
        for component in components {
            let word = String(component)
            
            // Adjust duration based on word length with less variation
            // to prevent words from jumping around too much
            let wordLength = word.count
            
            // More conservative duration adjustment
            // Shorter range of variation (0.7-1.3 instead of 0.5-1.5)
            let durationFactor = max(0.7, min(1.3, Double(wordLength) / 5.0))
            let wordDuration = baseWordDuration * durationFactor
            
            // Ensure minimum duration for very short words
            let finalDuration = max(0.2, wordDuration)
            
            words.append(TranscriptionWord(
                text: word,
                timestamp: currentTime,
                duration: finalDuration
            ))
            
            // Add a small gap between words (fixed spacing helps prevent jumping)
            currentTime += finalDuration + 0.05
        }
        
        // Calculate total duration
        let totalDuration = words.last?.endTimestamp ?? currentTime
        
        return TimestampedTranscription(
            words: words,
            fullText: text,
            duration: totalDuration
        )
    }
    
    // Create from SFSpeechRecognitionResult which contains word timing
    static func from(result: SFSpeechRecognitionResult) -> TimestampedTranscription {
        var words: [TranscriptionWord] = []
        let fullText = result.bestTranscription.formattedString
        
        // If there are no segments, fallback to estimating timestamps
        if result.bestTranscription.segments.isEmpty {
            return fromPlainText(fullText)
        }
        
        // Initial delay
        let initialDelay = 0.1
        
        // Process segments
        var previousEndTime: TimeInterval = initialDelay
        
        // Extract words with their timestamps
        for segment in result.bestTranscription.segments {
            // Make sure we have valid values with minimum duration
            let timestamp = max(initialDelay, segment.timestamp)
            let duration = max(0.2, segment.duration) // Ensure more substantial minimum duration
            
            // Ensure words don't overlap by enforcing minimum spacing
            let adjustedTimestamp = max(timestamp, previousEndTime + 0.05)
            
            words.append(TranscriptionWord(
                text: segment.substring,
                timestamp: adjustedTimestamp,
                duration: duration
            ))
            
            // Update previous end time for next segment
            previousEndTime = adjustedTimestamp + duration
        }
        
        // If we have multiple words, validate and clean up the timing
        if words.count > 1 {
            // Ensure progressive timing (words should come one after another)
            for i in 1..<words.count {
                let prevWord = words[i-1]
                let currentWord = words[i]
                
                // If current word starts before previous ends, adjust it
                if currentWord.timestamp < prevWord.endTimestamp {
                    words[i].timestamp = prevWord.endTimestamp + 0.05
                }
            }
        }
        
        // Calculate total duration based on the last word
        let totalDuration: TimeInterval
        if let lastWord = words.last {
            totalDuration = lastWord.timestamp + (lastWord.duration ?? 0.5)
        } else {
            totalDuration = 0
        }
        
        // Sort words by timestamp to ensure they are in order
        words.sort { $0.timestamp < $1.timestamp }
        
        return TimestampedTranscription(
            words: words,
            fullText: fullText,
            duration: totalDuration
        )
    }
}