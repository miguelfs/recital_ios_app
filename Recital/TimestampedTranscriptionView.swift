import SwiftUI

struct TimestampedTranscriptionView: View {
    @ObservedObject var recordingManager: RecordingManager
    @State private var wordViews: [Int: String] = [:]
    @State private var shouldAutoScroll = true
    @State private var lastScrollPosition: CGPoint? = nil
    
    var body: some View {
        ScrollViewReader { scrollReader in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // If we don't have a recording playing or no transcription available
                    if recordingManager.currentTranscription.isEmpty {
                        Text("No transcription available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                    // If we're playing a recording with a transcription
                    else if recordingManager.isPlaying,
                            let currentRecording = recordingManager.currentlyPlaying,
                            let timestampedTranscription = currentRecording.timestampedTranscription {
                        
                        // Create identifiable word views with individual word IDs
                        VStack(alignment: .leading, spacing: 5) {
                            // Render the attributed text with word highlighting
                            // This now uses word-level IDs instead of one ID for the whole text
                            Text(attributedTranscription(timestampedTranscription))
                                .lineSpacing(5)
                                .padding()
                                .id("transcription")
                        }
                    }
                    // If we have a transcription but not timestamped
                    else {
                        Text(recordingManager.currentTranscription)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .background(Color(UIColor.systemBackground).opacity(0.7))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .onChange(of: recordingManager.currentWordIndex) { oldIndex, newIndex in
                // Only scroll if: 
                // 1. We have a new index
                // 2. Auto-scroll is enabled
                // 3. The change is significant (prevents scrolling for minor timing adjustments)
                if let newIndex = newIndex, shouldAutoScroll, 
                   (oldIndex == nil || abs((oldIndex ?? 0) - newIndex) > 3) {
                    
                    // Use a gentler animation to prevent jarring movement
                    withAnimation(.easeInOut(duration: 0.5)) {
                        scrollReader.scrollTo("transcription", anchor: .center)
                    }
                }
            }
            // Allow disabling auto-scroll with a tap
            .onTapGesture {
                shouldAutoScroll.toggle()
            }
        }
    }
    
    // Create an attributed string with the current word highlighted in bold
    private func attributedTranscription(_ transcription: TimestampedTranscription) -> AttributedString {
        var attributedString = AttributedString("")
        
        // Exit early if no words in transcription
        if transcription.words.isEmpty {
            return AttributedString(transcription.fullText)
        }
        
        // Get current word index, defaulting to 0 if nil
        let currentIndex = recordingManager.currentWordIndex ?? 0
        
        // Build the entire attributed string
        for (index, word) in transcription.words.enumerated() {
            var wordAttr = AttributedString(word.text)
            
            // Add custom attribute for word index
            wordAttr[WordIndexKey.self] = index
            
            // Apply highlighting with smoother visual experience:
            // 1. Current word: Strongly highlighted
            // 2. Adjacent words: Slightly less dim
            // 3. Far away words: Dimmed
            if index == currentIndex {
                // Current word - full highlight
                wordAttr.inlinePresentationIntent = .stronglyEmphasized
                wordAttr.foregroundColor = .primary
                wordAttr.backgroundColor = Color.yellow.opacity(0.3)
                wordAttr.font = .system(size: 16, weight: .bold)
            } else if abs(index - currentIndex) <= 2 {
                // Near words - less dimmed (slightly emphasized)
                wordAttr.foregroundColor = .primary.opacity(0.8)
                wordAttr.font = .system(size: 15, weight: .regular)
            } else {
                // Far words - more dimmed
                wordAttr.foregroundColor = .secondary.opacity(0.7)
                wordAttr.font = .system(size: 15, weight: .regular)
            }
            
            // Append the word
            attributedString.append(wordAttr)
            
            // Add space if not the last word
            if index < transcription.words.count - 1 {
                attributedString.append(AttributedString(" "))
            }
        }
        
        return attributedString
    }
    
    // Define a custom attribute name for word indices
    private struct WordIndexKey: AttributedStringKey {
        typealias Value = Int
        static let name = "wordIndex"
    }
}

#Preview {
    TimestampedTranscriptionView(recordingManager: RecordingManager())
}