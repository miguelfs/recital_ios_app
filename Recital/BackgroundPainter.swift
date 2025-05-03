import SwiftUI
import Combine

// MARK: - Color Brush Model
struct ColorBrush: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: Double
    
    // Animation properties
    var offset: CGSize = .zero
    var animationPhase: Double = Double.random(in: 0...2 * .pi)  // Random starting phase
    var animationSpeed: Double = Double.random(in: 0.5...1.5)    // Random speed multiplier
    var animationRadius: Double = Double.random(in: 10...30)     // Random movement range
    
    static func == (lhs: ColorBrush, rhs: ColorBrush) -> Bool {
        lhs.id == rhs.id
    }
    
    // Update the floating animation based on time
    mutating func updateFloatingAnimation(time: TimeInterval) {
        // Circular motion pattern
        let xOffset = CGFloat(animationRadius * sin(time * animationSpeed + animationPhase))
        let yOffset = CGFloat(animationRadius * cos(time * 0.7 * animationSpeed + animationPhase))
        offset = CGSize(width: xOffset, height: yOffset)
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
    case ribbons = "Ribbons"
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
    
    // Track if audio level is significant enough to add new brushes
    private var shouldAddBrushes = false
    
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
        
        // Update each brush's position
        for i in 0..<brushes.count {
            if i < brushes.count {  // Safety check for concurrent modifications
                var brush = brushes[i]
                brush.updateFloatingAnimation(time: animationTime)
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
    
    func update(frequency: Float, level: CGFloat, color: Color, in screenSize: CGSize) {
        guard isActive else { return }
        
        // Only add new brushes when audio level is significant
        shouldAddBrushes = level > 0.1
        
        // Add new brushes at a controlled rate to avoid filling the canvas too quickly
        updateCounter += 1
        if updateCounter >= updateFrequency && shouldAddBrushes {
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
    
    func cycleToNextStyle() {
        let allStyles = PaintingStyle.allCases
        guard let currentIndex = allStyles.firstIndex(of: currentStyle) else { return }
        let nextIndex = (currentIndex + 1) % allStyles.count
        currentStyle = allStyles[nextIndex]
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
        case .ribbons:
            return createRibbonBrushes(frequency: frequency, level: level, color: color, screenSize: screenSize)
        case .bubbles:
            return createBubbleBrushes(frequency: frequency, level: level, color: color, screenSize: screenSize)
        case .waves:
            return createWaveBrushes(frequency: frequency, level: level, color: color, screenSize: screenSize)
        }
    }
    
    // Strategy 1: Ribbons - horizontal color streaks that extend across the screen
    private func createRibbonBrushes(
        frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize
    ) -> [ColorBrush] {
        // Only create ribbons when there's significant audio
        guard level > 0.1 else { return [] }
        
        // Create 1-2 ribbons at a time to allow gradual filling
        let numberOfRibbons = min(Int(level * 2) + 1, 2)
        
        var newBrushes: [ColorBrush] = []
        
        for _ in 0..<numberOfRibbons {
            // Randomize height position but ensure good distribution across the screen
            let ySection = CGFloat.random(in: 0...4) / 4.0  // Divide screen into 5 sections
            let y = screenSize.height * ySection + CGFloat.random(in: -20...20)  // Add some randomness
            let position = CGPoint(x: screenSize.width * 0.5, y: y)
            
            // Vary the size based on audio level and a bit of randomness
            let size = (15.0 + level * 25.0) * CGFloat.random(in: 0.8...1.2)
            
            // Slightly vary the ribbon color
            let hueAdjust = Double.random(in: -0.05...0.05)
            let baseColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let adjustedColor = Color(hue: Double(h) + hueAdjust, 
                                     saturation: Double(s), 
                                     brightness: Double(b), 
                                     opacity: Double(a))
            
            let brush = ColorBrush(
                position: position,
                color: adjustedColor,
                size: size,
                opacity: 0.7  // Fixed opacity for persistent visual elements
            )
            
            newBrushes.append(brush)
        }
        
        return newBrushes
    }
    
    // Strategy 2: Bubbles - circular spots that appear at random locations
    private func createBubbleBrushes(
        frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize
    ) -> [ColorBrush] {
        // Only create bubbles when there's audio
        guard level > 0.05 else { return [] }
        
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
    
    // Strategy 3: Waves - flowing patterns that move across the screen from bottom to top
    private func createWaveBrushes(
        frequency: Float,
        level: CGFloat,
        color: Color,
        screenSize: CGSize
    ) -> [ColorBrush] {
        // Only create waves when there's audio
        guard level > 0.05 else { return [] }
        
        var newBrushes: [ColorBrush] = []
        
        // Create waves at different heights to fill the screen more gradually
        let numberOfWaves = 2  // Just add a couple each time
        
        for _ in 0..<numberOfWaves {
            // Position waves at random heights
            let yPosition = CGFloat.random(in: 0...screenSize.height)
            
            // Create wave positions with a pattern that depends on frequency
            let frequencyFactor = CGFloat(frequency) / 2000.0
            let xPosition = CGFloat.random(in: 0...screenSize.width)
            
            let position = CGPoint(x: xPosition, y: yPosition)
            
            // Size based on audio level
            let size = 15.0 + level * 50.0
            
            // Make color variations based on position on screen
            let baseColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Vary color based on vertical position
            let hueAdjust = Double(yPosition) / Double(screenSize.height) * 0.2
            let adjustedColor = Color(hue: Double(h) + hueAdjust, 
                                     saturation: Double(s), 
                                     brightness: Double(b), 
                                     opacity: Double(a))
            
            let brush = ColorBrush(
                position: position,
                color: adjustedColor,
                size: size,
                opacity: 0.7  // Fixed opacity for persistence
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
            
            // Render each brush as a shape
            ForEach(painter.brushes) { brush in
                switch painter.currentStyle {
                case .ribbons:
                    Capsule()
                        .fill(brush.color)
                        .frame(width: screenSize.width * 1.5, height: brush.size)
                        .position(brush.position)
                        .offset(brush.offset)  // Apply floating animation offset
                        .opacity(brush.opacity)
                        .blur(radius: brush.size * 0.1)  // Lighter blur for better visibility
                        
                case .bubbles:
                    Circle()
                        .fill(brush.color)
                        .frame(width: brush.size, height: brush.size)
                        .position(brush.position)
                        .offset(brush.offset)  // Apply floating animation offset
                        .opacity(brush.opacity)
                        .blur(radius: brush.size * 0.1)  // Lighter blur
                        
                case .waves:
                    Ellipse()  // More elliptical for wave shape
                        .fill(brush.color)
                        .frame(width: brush.size, height: brush.size * 0.7)
                        .position(brush.position)
                        .offset(brush.offset)  // Apply floating animation offset
                        .opacity(brush.opacity)
                        .blur(radius: brush.size * 0.15)
                }
            }
        }
        .drawingGroup()  // Use Metal rendering for better performance
    }
}
