import Foundation

// IMPORTANT: 
// Add the following keys to your Info.plist to enable speech recognition and microphone access:
/*
<key>NSSpeechRecognitionUsageDescription</key>
<string>Recital needs speech recognition to transcribe your audio recordings</string>
<key>NSMicrophoneUsageDescription</key>
<string>Recital needs microphone access to record audio</string>
*/

// How to add these keys:
// 1. Open your project in Xcode
// 2. Select your app target and go to the "Info" tab
// 3. Add these two keys and their descriptions

// Or, if you prefer to edit the Info.plist file directly:
// 1. Right-click on Info.plist in the Project Navigator
// 2. Choose "Open As" > "Source Code"
// 3. Add the keys before the closing </dict> tag

// NOTE: This Swift file does not automatically add the permissions to Info.plist.
// It serves as a reminder of what needs to be added manually.