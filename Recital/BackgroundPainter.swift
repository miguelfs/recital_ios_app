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
    var animationSpeed: Double = Double.random(in: 0.9...2.6)    // More variation in speed
    var animationRadius: Double = Double.random(in: 25...70)     // Much larger movement range
    var secondaryPhase: Double = Double.random(in: 0...2 * .pi)  // Secondary motion phase
    var tertiaryPhase: Double = Double.random(in: 0...2 * .pi)   // Tertiary motion phase
    var buoyancyFactor: Double = Double.random(in: 0.8...1.9)    // Random buoyancy (affects vertical movement)
    var driftFactor: Double = Double.random(in: -0.9...0.9)      // Random horizontal drift tendency
    var isAnimating: Bool = true   // Always animate bubbles
    
    static func == (lhs: ColorBrush, rhs: ColorBrush) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, position, color, size, opacity
        case animationPhase, animationSpeed, animationRadius
        case secondaryPhase, tertiaryPhase, buoyancyFactor, driftFactor
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
        
        // Decode new animation properties with fallbacks for backward compatibility
        secondaryPhase = try container.decodeIfPresent(Double.self, forKey: .secondaryPhase) ?? Double.random(in: 0...2 * .pi)
        tertiaryPhase = try container.decodeIfPresent(Double.self, forKey: .tertiaryPhase) ?? Double.random(in: 0...2 * .pi)
        buoyancyFactor = try container.decodeIfPresent(Double.self, forKey: .buoyancyFactor) ?? Double.random(in: 0.8...1.3)
        driftFactor = try container.decodeIfPresent(Double.self, forKey: .driftFactor) ?? Double.random(in: -0.3...0.3)
        
        // Initialize other properties with defaults
        offset = .zero
        isAnimating = true  // Always animate
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
        
        // Encode new animation properties
        try container.encode(secondaryPhase, forKey: .secondaryPhase)
        try container.encode(tertiaryPhase, forKey: .tertiaryPhase)
        try container.encode(buoyancyFactor, forKey: .buoyancyFactor)
        try container.encode(driftFactor, forKey: .driftFactor)
    }
    
    // Update the floating animation based on time - now with much more realistic bubble physics
    mutating func updateFloatingAnimation(time: TimeInterval, volumeLevel: CGFloat) {
        // Always animate, regardless of volume level (bubbles always float)
        isAnimating = true
        
        // Calculate time-varying factors for natural acceleration/deceleration
        let timeScale = time * 0.5  // Slow down the overall time factor
        
        // Base radius (size-dependent - larger bubbles have less erratic movement)
        let sizeInfluence = max(0.5, 1.0 - Double(size) / 200.0)  // Smaller bubbles move more
        let baseRadius = animationRadius * sizeInfluence * 1.5
        
        // Apply both audio level and natural variation to movement
        let energyFactor = 0.6 + sin(timeScale * 0.2) * 0.4 + Double(min(0.5, volumeLevel))
        let dynamicRadius = baseRadius * energyFactor
        
        // Create complex naturalistic movement pattern combining several oscillations
        
        // 1. Primary circular motion - the base movement pattern
        let primaryX = dynamicRadius * sin(timeScale * animationSpeed + animationPhase)
        
        // Vertical motion is affected by buoyancy - makes bubbles tend to rise with variation
        let buoyancyEffect = cos(timeScale * 0.3) * 0.3 * buoyancyFactor  // Gentle oscillating buoyancy
        let primaryY = dynamicRadius * (cos(timeScale * 0.7 * animationSpeed + animationPhase) - buoyancyEffect)
        
        // 2. Secondary orbital motion - adds complexity to the path
        let secondaryScale = 0.45 * baseRadius  // Scale of the secondary motion
        let secondarySpeed = animationSpeed * 1.33  // Different frequency creates complex patterns
        let secondaryX = secondaryScale * sin(timeScale * secondarySpeed + secondaryPhase)
        let secondaryY = secondaryScale * cos(timeScale * secondarySpeed * 0.8 + secondaryPhase)
        
        // 3. Tertiary fine detail motion - subtle faster oscillations 
        let tertiaryScale = 0.15 * baseRadius  // Small tertiary motion
        let tertiarySpeed = animationSpeed * 2.7  // Much faster than primary
        let tertiaryX = tertiaryScale * sin(timeScale * tertiarySpeed + tertiaryPhase) 
        let tertiaryY = tertiaryScale * cos(timeScale * tertiarySpeed * 0.9 + tertiaryPhase)
        
        // 4. Slow drift - gradual directional movement
        let driftX = driftFactor * baseRadius * sin(timeScale * 0.05)
        let driftY = buoyancyFactor * baseRadius * 0.2 * (1 - cos(timeScale * 0.08))  // Slow upward tendency
        
        // 5. Path distortion - stretches the movement in certain directions periodically
        let pathDistortionX = sin(timeScale * 0.13) * 0.2  // Subtle stretch effect
        let stretchedX = primaryX * (1 + pathDistortionX)
        
        // Combine all motion components
        let compositeX = stretchedX + secondaryX + tertiaryX + driftX
        let compositeY = primaryY + secondaryY + tertiaryY + driftY
        
        // Apply a non-linear acceleration/deceleration effect to create more naturalistic motion
        // This simulates how real bubbles speed up and slow down in fluid
        let accelerationFactor = 0.5 + sin(timeScale * 0.17) * 0.5  // Varies between 0 and 1
        let accelX = compositeX * (1 + accelerationFactor * 0.3)
        let accelY = compositeY * (1 + accelerationFactor * 0.3)
        
        // Convert to target position
        let targetX = CGFloat(accelX)
        let targetY = CGFloat(accelY)
        
        // Apply a dynamic interpolation factor that changes with acceleration
        // This makes transitions between positions smoother or sharper depending on speed
        let baseInterpolation: CGFloat = 0.05  // Base smooth factor
        let dynamicInterpolation = baseInterpolation * (0.7 + CGFloat(accelerationFactor) * 0.6)
        
        // Apply environmental turbulence - occasional random variations
        let turbulence = sin(timeScale * 0.29) > 0.9  // Only apply turbulence occasionally
        let turbulenceFactor: CGFloat = turbulence ? CGFloat.random(in: 0.95...1.15) : 1.0
        
        let finalInterpolation = dynamicInterpolation * turbulenceFactor
        
        // Apply smooth movement toward target position
        offset.width += (targetX - offset.width) * finalInterpolation
        offset.height += (targetY - offset.height) * finalInterpolation
        
        // Rare random "kick" to simulate collision or sudden current change (1% chance per update)
        if Double.random(in: 0...1) < 0.01 {
            let kickMagnitude = CGFloat(0.3 + Double.random(in: 0...0.7) * sizeInfluence)
            let kickAngle = CGFloat.random(in: 0...(2 * .pi))
            let kickX = cos(kickAngle) * kickMagnitude
            let kickY = sin(kickAngle) * kickMagnitude
            
            offset.width += kickX
            offset.height += kickY
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
    case waves = "Waves"
    
    var id: String { self.rawValue }
}

// MARK: - Background Painter Model
class BackgroundPainter: ObservableObject {
    @Published var brushes: [ColorBrush] = []
    @Published var currentStyle: PaintingStyle = .bubbles
    @Published var isActive: Bool = false
    
    // Maximum number of brushes to keep on canvas
    private let maxBrushes = 1000  // Increased to allow many persistent bubbles (one per recording)
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
    
    // Key for storing background state in UserDefaults
    private let backgroundStateKey = "com.recital.backgroundState"
    
    init() {
        // Load saved style preference if available
        if let savedStyleString = UserDefaults.standard.string(forKey: "com.recital.preferredStyle"),
           let savedStyle = PaintingStyle(rawValue: savedStyleString) {
            currentStyle = savedStyle
        }
        
        // Load any saved background state
        loadBackgroundState()
        startFloatingAnimation()
    }
    
    // MARK: - Persistence
    
    // Save the current background bubbles to UserDefaults
    func saveBackgroundState() {
        do {
            let data = try JSONEncoder().encode(brushes)
            UserDefaults.standard.set(data, forKey: backgroundStateKey)
        } catch {
            print("Error saving background state: \(error.localizedDescription)")
        }
    }
    
    // Load the background bubbles from UserDefaults
    private func loadBackgroundState() {
        if let data = UserDefaults.standard.data(forKey: backgroundStateKey) {
            do {
                let savedBrushes = try JSONDecoder().decode([ColorBrush].self, from: data)
                DispatchQueue.main.async {
                    self.brushes = savedBrushes
                    
                    // Activate if we have bubbles
                    if !savedBrushes.isEmpty {
                        self.isActive = true
                    }
                }
            } catch {
                print("Error loading background state: \(error.localizedDescription)")
            }
        }
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
        // Using a higher framerate for smoother animation
        floatingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
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
        
        // Update animation time with a gentler slow motion factor
        // This controls the overall speed of the bubble movement animation
        animationTime += deltaTime * 0.12  // Even slower factor for more natural movement
        
        // Update each brush's position with current audio level for intensity
        // Use a minimum volume level to ensure animation always happens
        let effectiveLevel = max(0.25, currentAudioLevel)
        
        for i in 0..<brushes.count {
            if i < brushes.count {  // Safety check for concurrent modifications
                var brush = brushes[i]
                brush.updateFloatingAnimation(time: animationTime, volumeLevel: effectiveLevel)
                brushes[i] = brush
            }
        }
    }
    
    func startPainting() {
        isActive = true
        updateCounter = 0
        
        // We no longer clear existing bubbles
        // Each recording will add a new bubble to the existing ones
        
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
    
    // This method is now used only for tracking audio levels during recording, not adding bubbles
    func update(frequency: Float, level: CGFloat, color: Color, in screenSize: CGSize) {
        guard isActive else { return }
        
        // Update the current audio level for animations
        // Use smoothing to avoid jerky changes
        let smoothing: CGFloat = 0.3
        currentAudioLevel = currentAudioLevel * (1 - smoothing) + level * smoothing
    }
    
    // Add a single bubble at the end of recording that represents the entire recording
    func addSummaryBubble(averageFrequency: Float, maxLevel: CGFloat, in screenSize: CGSize) {
        // Generate a position that won't overlap too much with existing bubbles
        let position = findOptimalBubblePosition(in: screenSize)
        
        // Determine size based on max level (louder = bigger)
        let sizeMultiplier: CGFloat = 2.0  // Make bubbles more prominent
        let size = max(40.0, min(120.0, 40.0 + maxLevel * 150.0 * sizeMultiplier))
        
        // Determine color based on frequency ranges
        let color = colorForFrequency(averageFrequency)
        
        // Create the bubble
        let bubble = ColorBrush(
            position: position,
            color: color,
            size: size,
            opacity: 0.7  // Higher opacity for more visibility
        )
        
        // Add the bubble with animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            brushes.append(bubble)
            
            // Limit the total number of bubbles if needed
            // Remove the oldest bubbles if we exceed the maximum
            if brushes.count > maxBrushes {
                // Remove oldest bubbles (those at the start of the array)
                let excessCount = brushes.count - maxBrushes
                brushes.removeFirst(excessCount)
            }
        }
        
        // Ensure the background painter is active so the bubble will animate
        isActive = true
        startFloatingAnimation()
        
        // Save the background state
        saveBackgroundState()
    }
    
    // Allow switching between different styles (bubbles/waves)
    func cycleToNextStyle() {
        let allStyles = PaintingStyle.allCases
        guard let currentIndex = allStyles.firstIndex(of: currentStyle) else { return }
        let nextIndex = (currentIndex + 1) % allStyles.count
        currentStyle = allStyles[nextIndex]
        
        // Save the style preference
        UserDefaults.standard.set(currentStyle.rawValue, forKey: "com.recital.preferredStyle")
        
        // Also save the background state since the visual appearance has changed
        saveBackgroundState()
    }
    
    // Helper to find a position for the new bubble that avoids overlap with existing bubbles
    private func findOptimalBubblePosition(in screenSize: CGSize) -> CGPoint {
        // Define safe margins to keep bubbles away from screen edges
        let margin: CGFloat = 80.0
        
        // If no bubbles yet, place in a random position (not just center)
        if brushes.isEmpty {
            return CGPoint(
                x: CGFloat.random(in: margin...(screenSize.width - margin)),
                y: CGFloat.random(in: margin...(screenSize.height - margin))
            )
        }
        
        // Try several random positions and pick the one with least overlap
        var bestPosition = CGPoint(
            x: CGFloat.random(in: margin...(screenSize.width - margin)),
            y: CGFloat.random(in: margin...(screenSize.height - margin))
        )
        var leastOverlap: CGFloat = .infinity
        
        for _ in 0..<15 {  // Try 15 positions for better distribution
            let testPosition = CGPoint(
                x: CGFloat.random(in: margin...(screenSize.width - margin)),
                y: CGFloat.random(in: margin...(screenSize.height - margin))
            )
            
            var totalOverlap: CGFloat = 0
            for brush in brushes {
                let distance = sqrt(pow(testPosition.x - brush.position.x, 2) + 
                                   pow(testPosition.y - brush.position.y, 2))
                // Use the actual bubble size for overlap calculation
                let combinedRadius = brush.size / 2.0 + 60.0 // Add extra space between bubbles
                
                if distance < combinedRadius {
                    totalOverlap += combinedRadius - distance
                }
            }
            
            if totalOverlap < leastOverlap {
                leastOverlap = totalOverlap
                bestPosition = testPosition
                
                // If we found a position with no overlap, use it immediately
                if leastOverlap == 0 {
                    break
                }
            }
        }
        
        // Add a small random offset to make positions less predictable
        let randomOffset = CGPoint(
            x: CGFloat.random(in: -15...15),
            y: CGFloat.random(in: -15...15)
        )
        
        let finalPosition = CGPoint(
            x: max(margin, min(screenSize.width - margin, bestPosition.x + randomOffset.x)),
            y: max(margin, min(screenSize.height - margin, bestPosition.y + randomOffset.y))
        )
        
        return finalPosition
    }
    
    // Create a color based on frequency
    private func colorForFrequency(_ frequency: Float) -> Color {
        // Low frequency = red/orange
        if frequency < 150 {
            return Color(hue: Double.random(in: 0.0...0.1), saturation: 0.9, brightness: 0.9)
        }
        // Mid frequency = yellow/green
        else if frequency < 500 {
            return Color(hue: Double.random(in: 0.1...0.4), saturation: 0.9, brightness: 0.9)
        }
        // High frequency = blue/purple
        else {
            return Color(hue: Double.random(in: 0.5...0.8), saturation: 0.8, brightness: 0.9)
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
        switch strategy {
        case .bubbles:
            return createBubbleBrushes(frequency: frequency, level: level, color: color, screenSize: screenSize)
        case .waves:
            return createWaveBrushes(frequency: frequency, level: level, color: color, screenSize: screenSize)
        }
    }
    
    // Create bubble brushes - circular spots that appear at random locations
    private func createBubbleBrushes(
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
    
    // Strategy for waves - flowing patterns that move across the screen
    private func createWaveBrushes(
        frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize
    ) -> [ColorBrush] {
        var newBrushes: [ColorBrush] = []
        
        // Create a few wave elements at different positions
        let numberOfWaves = min(Int(level * 4) + 1, 4)
        
        for _ in 0..<numberOfWaves {
            // Position waves at varying heights with emphasis on screen edges
            let distribution = Double.random(in: 0...1)
            let yPosition: CGFloat
            
            if distribution < 0.7 {
                // 70% chance to place near top or bottom for a flowing effect
                if Bool.random() {
                    // Top area
                    yPosition = CGFloat.random(in: 50...screenSize.height * 0.3)
                } else {
                    // Bottom area
                    yPosition = CGFloat.random(in: screenSize.height * 0.7...screenSize.height - 50)
                }
            } else {
                // 30% chance to place in middle area
                yPosition = CGFloat.random(in: screenSize.height * 0.3...screenSize.height * 0.7)
            }
            
            // Spread across the full width
            let xPosition = CGFloat.random(in: 50...screenSize.width - 50)
            
            let position = CGPoint(x: xPosition, y: yPosition)
            
            // Make wave size depend on audio level and frequency
            // Lower frequencies make larger waves
            let frequencyFactor = max(0.3, min(1.0, 1.0 - CGFloat(frequency) / 4000.0))
            // Make waves wider than tall
            let size = (30.0 + level * 70.0 * frequencyFactor) * CGFloat.random(in: 0.8...1.2)
            
            // Create color variation based on position and frequency
            let baseColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Vertical position affects color - gradual shift from top to bottom
            let verticalFactor = yPosition / screenSize.height
            let hueAdjust = Double(verticalFactor) * 0.2 + Double.random(in: -0.05...0.05)
            
            let adjustedColor = Color(
                hue: Double(h) + hueAdjust,
                saturation: Double(s) * (0.9 + Double.random(in: -0.1...0.1)),
                brightness: Double(b) * (0.9 + Double.random(in: -0.1...0.1)),
                opacity: Double(a)
            )
            
            // Create wave brush with higher movement values
            var brush = ColorBrush(
                position: position,
                color: adjustedColor,
                size: size,
                opacity: 0.65  // Slightly higher opacity for waves
            )
            
            // Customize animation properties for wave-like movement
            brush.animationSpeed = Double.random(in: 0.15...0.4)  // Slower for wave-like motion
            brush.animationRadius = Double.random(in: 40...100)   // Larger radius for flowing movement
            brush.buoyancyFactor = Double.random(in: 0.5...1.2)   // Less vertical tendency
            brush.driftFactor = Double.random(in: 0.5...1.5) * (Bool.random() ? 1 : -1)  // Strong horizontal drift
            
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
            
            // Render each brush based on the current style
            ForEach(painter.brushes) { brush in
                // Use a specific shape based on the painting style
                Group {
                    if painter.currentStyle == .bubbles {
                        // Bubble shape (circle)
                        Circle()
                            .fill(brush.color)
                            .frame(width: brush.size, height: brush.size)
                            .position(brush.position)
                            .offset(brush.offset)  // Apply floating animation offset
                            .opacity(brush.opacity)
                            .blur(radius: brush.size * 0.1)  // Lighter blur for bubbles
                    } else {
                        // Wave shape (ellipse - more horizontal)
                        Ellipse()
                            .fill(brush.color)
                            .frame(width: brush.size * 1.7, height: brush.size * 0.6)  // More elongated for waves
                            .position(brush.position)
                            .offset(brush.offset)  // Apply floating animation offset
                            .opacity(brush.opacity)
                            .blur(radius: brush.size * 0.15)  // Slightly more blur for waves
                            .rotationEffect(
                                // Slight rotation based on movement to create flow effect
                                Angle(degrees: Double(
                                    -10 + (brush.offset.width / CGFloat(brush.animationRadius)) * 20)
                                )
                            )
                    }
                }
                // Add a common shadow effect for both styles
                .shadow(color: brush.color.opacity(0.3), radius: 3, x: 1, y: 1)
            }
        }
        .drawingGroup()  // Use Metal rendering for better performance
    }
}
