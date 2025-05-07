import SwiftUI
import Combine

// MARK: - Color Brush Model
struct ColorBrush: Identifiable, Equatable, Codable {
    let id: UUID
    var position: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: Double
    
    init(id: UUID = UUID(), position: CGPoint, color: Color, size: CGFloat, opacity: Double) {
        self.id = id
        self.position = position
        self.color = color
        self.size = size
        self.opacity = opacity
    }
    
    // Animation properties
    var offset: CGSize = .zero
    var animationPhase: Double = Double.random(in: 0...2 * .pi)  // Random starting phase
    var animationSpeed: Double = Double.random(in: 0.5...1.5)    // Random speed multiplier
    var animationRadius: Double = Double.random(in: 10...30)     // Random movement range
    var isAnimating: Bool = false  // Only animate if volume is above threshold
    
    static func == (lhs: ColorBrush, rhs: ColorBrush) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, position, color, size, opacity
        case animationPhase, animationSpeed, animationRadius
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode ID
        id = try container.decode(UUID.self, forKey: .id)
        
        // Decode position - need to handle CGPoint
        let positionData = try container.decode([String: CGFloat].self, forKey: .position)
        position = CGPoint(x: positionData["x"] ?? 0, y: positionData["y"] ?? 0)
        
        // Decode color - need to handle SwiftUI Color
        let colorData = try container.decode([String: Double].self, forKey: .color)
        let red = colorData["red"] ?? 0
        let green = colorData["green"] ?? 0
        let blue = colorData["blue"] ?? 0
        let alpha = colorData["alpha"] ?? 1
        color = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        
        // Decode simple properties
        size = try container.decode(CGFloat.self, forKey: .size)
        opacity = try container.decode(Double.self, forKey: .opacity)
        animationPhase = try container.decode(Double.self, forKey: .animationPhase)
        animationSpeed = try container.decode(Double.self, forKey: .animationSpeed)
        animationRadius = try container.decode(Double.self, forKey: .animationRadius)
        
        // Initialize other properties with defaults
        offset = .zero
        isAnimating = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode ID
        try container.encode(id, forKey: .id)
        
        // Encode position - need to handle CGPoint
        let positionData: [String: CGFloat] = ["x": position.x, "y": position.y]
        try container.encode(positionData, forKey: .position)
        
        // Encode color - need to handle SwiftUI Color
        // Convert Color to UIColor to get components
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorData: [String: Double] = [
            "red": Double(red),
            "green": Double(green),
            "blue": Double(blue),
            "alpha": Double(alpha)
        ]
        try container.encode(colorData, forKey: .color)
        
        // Encode simple properties
        try container.encode(size, forKey: .size)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(animationPhase, forKey: .animationPhase)
        try container.encode(animationSpeed, forKey: .animationSpeed)
        try container.encode(animationRadius, forKey: .animationRadius)
    }
    
    // Update the floating animation based on time and volume level
    mutating func updateFloatingAnimation(time: TimeInterval, volumeLevel: CGFloat) {
        // Only animate if volume is above threshold (0.45)
        if volumeLevel > 0.45 {
            isAnimating = true
            
            // Adjust movement size based on volume for more dynamic effect
            let adjustedRadius = animationRadius * Double(1.0 + volumeLevel * 0.5)
            
            // Circular motion pattern
            let xOffset = CGFloat(adjustedRadius * sin(time * animationSpeed + animationPhase))
            let yOffset = CGFloat(adjustedRadius * cos(time * 0.7 * animationSpeed + animationPhase))
            
            // Gradually move to the new position for smoother transitions
            let targetOffset = CGSize(width: xOffset, height: yOffset)
            let interpolation: CGFloat = 0.1  // Smooth transition factor
            
            offset.width += (targetOffset.width - offset.width) * interpolation
            offset.height += (targetOffset.height - offset.height) * interpolation
        } else if isAnimating {
            // Gradually return to center when volume drops below threshold
            let interpolation: CGFloat = 0.05
            offset.width *= (1.0 - interpolation)
            offset.height *= (1.0 - interpolation)
            
            // Stop considering it animating once it's very close to center
            if abs(offset.width) < 0.5 && abs(offset.height) < 0.5 {
                isAnimating = false
                offset = .zero
            }
        }
    }
}

// MARK: - Background Painting Strategy Protocol
protocol BackgroundPaintingStrategy {
    func updateBrushes(
        with frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize,
        strategy: PaintingStyle
    ) -> [ColorBrush]
}

// MARK: - Painting Style Enum
enum PaintingStyle: String, CaseIterable, Identifiable {
    case bubbles = "Bubbles"
    
    var id: String { self.rawValue }
}

// MARK: - Background Painter Model
class BackgroundPainter: ObservableObject {
    @Published var brushes: [ColorBrush] = []
    @Published var currentStyle: PaintingStyle = .bubbles
    @Published var isActive: Bool = false
    
    // Maximum number of brushes to keep on canvas
    private let maxBrushes = 300  // Increased to allow more persistent brushes
    private let strategy = DefaultPaintingStrategy()
    private var cancellables = Set<AnyCancellable>()
    
    // Control how frequently new brushes are added (to prevent overwhelming the canvas)
    private var updateCounter = 0
    private let updateFrequency = 3  // Only add brushes every Nth update
    
    // Animation timer and state
    private var floatingAnimationTimer: Timer?
    private var animationTime: TimeInterval = 0
    private var lastUpdateTime: Date = Date()
    
    // Audio level tracking
    private var currentAudioLevel: CGFloat = 0.0
    private let brushThreshold: CGFloat = 0.5       // Much higher threshold for creating new brushes
    private let animationThreshold: CGFloat = 0.45  // Much higher threshold for animating existing brushes
    
    init() {
        startFloatingAnimation()
    }
    
    deinit {
        stopFloatingAnimation()
    }
    
    // Start the floating animation timer
    private func startFloatingAnimation() {
        stopFloatingAnimation() // Stop any existing timer
        
        // Reset animation time
        animationTime = 0
        lastUpdateTime = Date()
        
        // Create a timer that updates the floating animation
        floatingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in
            self?.updateFloatingAnimation()
        }
    }
    
    // Stop the floating animation timer
    private func stopFloatingAnimation() {
        floatingAnimationTimer?.invalidate()
        floatingAnimationTimer = nil
    }
    
    // Update the floating animation
    private func updateFloatingAnimation() {
        // Calculate time delta since last update
        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = currentTime
        
        // Update animation time (slow motion)
        animationTime += deltaTime * 0.2  // Slow motion factor
        
        // Update each brush's position with current audio level for intensity
        for i in 0..<brushes.count {
            if i < brushes.count {  // Safety check for concurrent modifications
                var brush = brushes[i]
                brush.updateFloatingAnimation(time: animationTime, volumeLevel: currentAudioLevel)
                brushes[i] = brush
            }
        }
    }
    
    func startPainting() {
        isActive = true
        brushes.removeAll()
        updateCounter = 0
        
        // Ensure animation is running
        startFloatingAnimation()
    }
    
    func stopPainting() {
        isActive = false
        
        // Keep the canvas as is, but stop adding new brushes
        // No fading or removal of existing brushes
        
        // Animation continues even after stopping painting
    }
    
    func clearCanvas() {
        // Only use this method when explicitly wanting to clear the canvas
        withAnimation {
            brushes.removeAll()
        }
    }
    
    func loadBackground(from data: Data?) {
        guard let data = data else {
            // If no data is provided, just clear the canvas
            clearCanvas()
            return
        }
        
        do {
            let loadedBrushes = try JSONDecoder().decode([ColorBrush].self, from: data)
            withAnimation {
                brushes = loadedBrushes
            }
            // Start animation for loaded brushes
            isActive = true
            startFloatingAnimation()
        } catch {
            print("Error loading background: \(error.localizedDescription)")
            clearCanvas()
        }
    }
    
    func update(frequency: Float, level: CGFloat, color: Color, in screenSize: CGSize) {
        guard isActive else { return }
        
        // Update the current audio level for animations
        // Use smoothing to avoid jerky changes
        let smoothing: CGFloat = 0.3
        currentAudioLevel = currentAudioLevel * (1 - smoothing) + level * smoothing
        
        // Apply additional frequency-based threshold adjustment
        // Lower frequencies often have more ambient energy, so require higher threshold
        let frequencyFactor: CGFloat = min(1.0, CGFloat(frequency) / 1000.0)
        let adjustedThreshold = brushThreshold * (1.2 - frequencyFactor * 0.4)
        
        // Only add new brushes when audio level is above the adjusted threshold
        let shouldAddBrushes = level > adjustedThreshold
        
        // Add new brushes at a controlled rate to avoid filling the canvas too quickly
        updateCounter += 1
        // Use the frequency-adjusted threshold for brush creation
        if updateCounter >= updateFrequency && level > adjustedThreshold {
            updateCounter = 0
            
            // Add new brushes based on the current strategy
            let newBrushes = strategy.updateBrushes(
                with: frequency,
                level: level,
                color: color,
                screenSize: screenSize,
                strategy: currentStyle
            )
            
            // Add new brushes with a subtle animation
            withAnimation(.easeOut(duration: 0.2)) {
                brushes.append(contentsOf: newBrushes)
                
                // Only limit the total number of brushes if we exceed the maximum by a lot
                // This prevents the canvas from being cleared as it fills
                if brushes.count > maxBrushes + 50 {
                    brushes.removeFirst(50)  // Remove in batches to maintain most of the painting
                }
            }
        }
    }
    
}

// MARK: - Default Implementation of Background Painting Strategy
struct DefaultPaintingStrategy: BackgroundPaintingStrategy {
    func updateBrushes(
        with frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize,
        strategy: PaintingStyle
    ) -> [ColorBrush] {
        return createBrushes(frequency: frequency, level: level, color: color, screenSize: screenSize)
    }
    
    
    // Create bubble brushes - circular spots that appear at random locations
    private func createBrushes(
        frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize
    ) -> [ColorBrush] {
        // (volume threshold is now controlled by the BackgroundPainter class)
        
        // Create just 1-3 bubbles per update to gradually fill the canvas
        let numberOfBubbles = min(Int(level * 3) + 1, 3)
        
        var newBrushes: [ColorBrush] = []
        
        for _ in 0..<numberOfBubbles {
            // Ensure bubbles are distributed across the entire screen
            let x = CGFloat.random(in: 0...screenSize.width)
            let y = CGFloat.random(in: 0...screenSize.height)
            let position = CGPoint(x: x, y: y)
            
            // Size varies with audio level and frequency (higher frequency = smaller bubbles)
            let frequencyFactor = max(0.2, min(1.0, 1.0 - CGFloat(frequency) / 5000.0))
            let size = (10.0 + level * 40.0 * frequencyFactor) * CGFloat.random(in: 0.7...1.3)
            
            // Slightly vary the bubble color based on frequency
            let hueAdjust = Double(frequency) / 5000.0
            let baseColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let adjustedColor = Color(hue: Double(h) + Double.random(in: -0.1...0.1), 
                                     saturation: Double(s), 
                                     brightness: Double(b), 
                                     opacity: Double(a))
            
            // Create bubble with consistent opacity for better visibility
            let brush = ColorBrush(
                position: position,
                color: adjustedColor,
                size: size,
                opacity: 0.6  // Fixed higher opacity for persistence
            )
            
            newBrushes.append(brush)
        }
        
        return newBrushes
    }
    
}

// MARK: - Background Canvas View
struct BackgroundCanvasView: View {
    @ObservedObject var painter: BackgroundPainter
    let screenSize: CGSize
    
    var body: some View {
        ZStack {
            // Semi-transparent background to make the colors pop
            Color(UIColor.systemBackground)
                .opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            // Render each brush as a circle (bubble)
            ForEach(painter.brushes) { brush in
                Circle()
                    .fill(brush.color)
                    .frame(width: brush.size, height: brush.size)
                    .position(brush.position)
                    .offset(brush.offset)  // Apply floating animation offset
                    .opacity(brush.opacity)
                    .blur(radius: brush.size * 0.1)  // Lighter blur
            }
        }
        .drawingGroup()  // Use Metal rendering for better performance
    }
}
