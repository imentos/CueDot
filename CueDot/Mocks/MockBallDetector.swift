import Foundation
import Vision
import simd
import QuartzCore
#if canImport(ARKit)
import ARKit
#endif

/// Mock implementation of BallDetectionProtocol for testing
/// Provides predictable ball detection results for unit tests and development
public class MockBallDetector: BallDetectionProtocol {
    
    // MARK: - Protocol Properties
    
    public var configuration: BallDetectionConfiguration {
        didSet {
            validateConfiguration()
        }
    }
    
    public private(set) var isActive: Bool = false
    public private(set) var lastProcessingTime: TimeInterval = 0
    
    // MARK: - Mock Configuration
    
    /// Predefined ball positions for consistent testing
    public var mockBallPositions: [simd_float3] = []
    
    /// Confidence levels for mock balls
    public var mockConfidenceLevels: [Double] = []
    
    /// Colors for mock balls
    public var mockBallColors: [BallColor] = []
    
    /// Ball numbers for mock balls
    public var mockBallNumbers: [Int] = []
    
    /// Whether to simulate processing delays
    public var simulateProcessingDelay: Bool = false
    
    /// Simulated processing delay in seconds
    public var processingDelay: TimeInterval = 0.01
    
    /// Whether to inject random noise into positions
    public var addPositionalNoise: Bool = false
    
    /// Standard deviation for positional noise
    public var noiseLevel: Double = 0.001
    
    /// Whether to simulate intermittent failures
    public var simulateFailures: Bool = false
    
    /// Probability of failure (0.0 - 1.0)
    public var failureProbability: Double = 0.05
    
    /// Performance metrics tracking
    private var performanceMetrics: [String: Double] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: BallDetectionConfiguration = BallDetectionConfiguration()) {
        self.configuration = configuration
        setupDefaultMockData()
        validateConfiguration()
    }
    
    // MARK: - Protocol Methods
    
    public func detectBalls(in pixelBuffer: CVPixelBuffer, 
                           cameraTransform: simd_float4x4,
                           timestamp: TimeInterval) throws -> [BallDetectionResult] {
        if simulateProcessingDelay {
            Thread.sleep(forTimeInterval: processingDelay)
        }
        
        let startTime = CACurrentMediaTime()
        
        // Simulate failure if configured
        if simulateFailures && Double.random(in: 0...1) < failureProbability {
            throw BallDetectionError.detectionFailed("Simulated detection failure")
        }
        
        var results: [BallDetectionResult] = []
        
        // Generate mock detection results
        for i in 0..<min(mockBallPositions.count, Int(configuration.maxBallsPerFrame)) {
            var position = mockBallPositions[i]
            
            // Add noise if configured
            if addPositionalNoise {
                position.x += Float.random(in: -Float(noiseLevel)...Float(noiseLevel))
                position.y += Float.random(in: -Float(noiseLevel)...Float(noiseLevel))
                position.z += Float.random(in: -Float(noiseLevel)...Float(noiseLevel))
            }
            
            let confidence = i < mockConfidenceLevels.count ? mockConfidenceLevels[i] : 0.95
            
            // Only include balls that meet minimum confidence threshold
            if confidence >= configuration.minimumConfidence {
                let result = BallDetectionResult(
                    ballCenter3D: position,
                    confidence: Float(confidence),
                    timestamp: timestamp,
                    isOccluded: false,
                    hasMultipleBalls: false
                )
                results.append(result)
            }
        }
        
        let processingTime = CACurrentMediaTime() - startTime
        lastProcessingTime = processingTime
        
        // Update performance metrics
        performanceMetrics["lastProcessingTime"] = processingTime * 1000 // Convert to ms
        performanceMetrics["detectionsCount"] = Double(results.count)
        performanceMetrics["averageConfidence"] = results.isEmpty ? 0 : results.map { Double($0.confidence) }.reduce(0, +) / Double(results.count)
        
        return results
    }
    
    public func detectBallsAsync(in pixelBuffer: CVPixelBuffer,
                                cameraTransform: simd_float4x4,
                                timestamp: TimeInterval,
                                completion: @escaping (Result<[BallDetectionResult], BallDetectionError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let results = try self?.detectBalls(in: pixelBuffer, 
                                                   cameraTransform: cameraTransform, 
                                                   timestamp: timestamp) ?? []
                DispatchQueue.main.async {
                    completion(.success(results))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error as? BallDetectionError ?? .detectionFailed("Unknown error")))
                }
            }
        }
    }
    
    /*
    #if canImport(ARKit)
    @available(iOS 11.0, *)
    public func detect(in arFrame: ARFrame) throws -> [BallDetectionResult] {
        return try detectBalls(in: arFrame.capturedImage, 
                              cameraTransform: arFrame.camera.transform,
                              timestamp: arFrame.timestamp)
    }
    #endif
    */
    
    /// Convenience method for testing - uses identity transform as default
    public func detect(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) throws -> [BallDetectionResult] {
        return try detectBalls(in: pixelBuffer, 
                              cameraTransform: matrix_identity_float4x4,
                              timestamp: timestamp)
    }
    
    public func startDetection() throws {
        if !isActive {
            isActive = true
            performanceMetrics["sessionsStarted"] = (performanceMetrics["sessionsStarted"] ?? 0) + 1
        }
    }
    
    public func stopDetection() {
        if isActive {
            isActive = false
            performanceMetrics["sessionsStopped"] = (performanceMetrics["sessionsStopped"] ?? 0) + 1
        }
    }
    
    public func reset() {
        stopDetection()
        performanceMetrics.removeAll()
        setupDefaultMockData()
    }
    
    public func getPerformanceMetrics() -> [String: Double] {
        var metrics = performanceMetrics
        metrics["isActive"] = isActive ? 1.0 : 0.0
        metrics["configuredMaxBalls"] = Double(configuration.maxBallsPerFrame)
        metrics["mockBallCount"] = Double(mockBallPositions.count)
        return metrics
    }
    
    public func meetsPerformanceRequirements(_ requirements: PerformanceRequirements) -> Bool {
        guard let lastProcessingTime = performanceMetrics["lastProcessingTime"] else { return false }
        
        // Check latency requirement
        if lastProcessingTime > requirements.maximumLatency * 1000 { // Convert to ms
            return false
        }
        
        // Check FPS requirement (mock data processing is fast enough)
        let fpsEstimate = 1000.0 / (lastProcessingTime > 0 ? lastProcessingTime : 1.0)
        if fpsEstimate < requirements.minimumFPS {
            return false
        }
        
        return true
    }
    
    // MARK: - Mock Data Management
    
    /// Set up default mock data for testing standard pool ball scenarios
    private func setupDefaultMockData() {
        // Standard 9-ball rack positions (simplified)
        mockBallPositions = [
            simd_float3(0.0, 0.0, 0.5),     // 1-ball at front
            simd_float3(-0.03, 0.0, 0.53),  // 2-ball
            simd_float3(0.03, 0.0, 0.53),   // 3-ball
            simd_float3(-0.06, 0.0, 0.56),  // 4-ball
            simd_float3(0.0, 0.0, 0.56),    // 9-ball (center)
            simd_float3(0.06, 0.0, 0.56),   // 6-ball
            simd_float3(-0.09, 0.0, 0.59),  // 7-ball
            simd_float3(-0.03, 0.0, 0.59),  // 8-ball
            simd_float3(0.03, 0.0, 0.59),   // 5-ball
            simd_float3(0.09, 0.0, 0.59)    // 10-ball (if using 10-ball)
        ]
        
        // Corresponding confidence levels (slightly varied for realism)
        mockConfidenceLevels = [0.98, 0.95, 0.97, 0.93, 0.99, 0.94, 0.96, 0.92, 0.95, 0.91]
        
        // Standard pool ball colors
        mockBallColors = [.yellow, .blue, .red, .purple, .orange, .green, .brown, .black, .yellow]
        
        // Ball numbers
        mockBallNumbers = [1, 2, 3, 4, 9, 6, 7, 8, 5]
    }
    
    /// Add a mock ball for testing
    public func addMockBall(position: simd_float3, 
                           confidence: Double = 0.95, 
                           color: BallColor = .white, 
                           ballNumber: Int? = nil) {
        mockBallPositions.append(position)
        mockConfidenceLevels.append(confidence)
        mockBallColors.append(color)
        if let number = ballNumber {
            mockBallNumbers.append(number)
        }
    }
    
    /// Remove all mock balls
    public func clearMockBalls() {
        mockBallPositions.removeAll()
        mockConfidenceLevels.removeAll()
        mockBallColors.removeAll()
        mockBallNumbers.removeAll()
    }
    
    /// Simulate ball movement by updating positions
    public func moveMockBall(at index: Int, to newPosition: simd_float3) {
        guard index < mockBallPositions.count else { return }
        mockBallPositions[index] = newPosition
    }
    
    /// Set specific mock scenario for testing
    public func setMockScenario(_ scenario: MockDetectionScenario) {
        clearMockBalls()
        
        switch scenario {
        case .empty:
            // No balls
            break
            
        case .singleBall:
            addMockBall(position: simd_float3(0, 0, 0.5), 
                       confidence: 0.98, 
                       color: BallColor.white,
                       ballNumber: 0)
            
        case .standardRack:
            setupDefaultMockData()
            
        case .scattered:
            // Random scattered positions
            for i in 1...6 {
                let x = Float.random(in: -0.3...0.3)
                let z = Float.random(in: 0.3...0.8)
                addMockBall(position: simd_float3(x, 0, z),
                           confidence: Double.random(in: 0.8...0.99),
                           color: BallColor.allCases.randomElement() ?? .white,
                           ballNumber: i)
            }
            
        case .lowConfidence:
            // Balls with low confidence levels
            setupDefaultMockData()
            mockConfidenceLevels = Array(repeating: 0.4, count: mockConfidenceLevels.count)
            
        case .partialOcclusion:
            // Some balls with very low confidence (simulating occlusion)
            setupDefaultMockData()
            for i in stride(from: 1, to: mockConfidenceLevels.count, by: 2) {
                mockConfidenceLevels[i] = 0.3 // Below typical threshold
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateConfiguration() {
        // Mock validation - in real implementation would validate camera settings, etc.
        performanceMetrics["configurationValid"] = 1.0
    }
    
    private func generateMockBoundingBox(for position: simd_float3) -> CGRect {
        // Generate a reasonable bounding box based on position
        let centerX = CGFloat(position.x * 100 + 320) // Scale and offset for screen coordinates
        let centerY = CGFloat(position.z * 100 + 240)
        let size: CGFloat = 30 // Approximate ball size in pixels
        
        return CGRect(
            x: centerX - size/2,
            y: centerY - size/2,
            width: size,
            height: size
        )
    }
    
    private func generateMockPixelCoordinates(for position: simd_float3) -> CGPoint {
        // Convert 3D position to 2D pixel coordinates (simplified projection)
        return CGPoint(
            x: CGFloat(position.x * 100 + 320),
            y: CGFloat(position.z * 100 + 240)
        )
    }
}

// MARK: - Mock Scenarios

/// Predefined scenarios for testing different detection conditions
public enum MockDetectionScenario {
    case empty              // No balls detected
    case singleBall         // Single cue ball
    case standardRack       // Standard 9-ball rack formation
    case scattered          // Balls in random positions
    case lowConfidence      // All detections below confidence threshold
    case partialOcclusion   // Some balls partially hidden
}

// MARK: - Mock Factory

/// Factory for creating pre-configured mock detectors
public struct MockBallDetectorFactory {
    
    /// Create a high-performance mock detector for testing
    public static func highPerformance() -> MockBallDetector {
        let config = BallDetectionConfiguration(
            colorFiltering: ColorFilteringSettings(),
            shapeDetection: ShapeDetectionSettings(),
            performance: DetectionPerformanceSettings()
        )
        
        let detector = MockBallDetector(configuration: config)
        detector.simulateProcessingDelay = false
        detector.addPositionalNoise = false
        detector.simulateFailures = false
        
        return detector
    }
    
    /// Create a realistic mock detector that simulates real-world conditions
    public static func realistic() -> MockBallDetector {
        let detector = MockBallDetector()
        detector.simulateProcessingDelay = true
        detector.processingDelay = 0.008 // ~8ms processing time
        detector.addPositionalNoise = true
        detector.noiseLevel = 0.001 // Small amount of noise
        detector.simulateFailures = true
        detector.failureProbability = 0.02 // 2% failure rate
        
        return detector
    }
    
    /// Create a mock detector for stress testing
    public static func stressTesting() -> MockBallDetector {
        let detector = MockBallDetector()
        detector.setMockScenario(.scattered)
        detector.simulateProcessingDelay = true
        detector.processingDelay = 0.02 // Slower processing
        detector.addPositionalNoise = true
        detector.noiseLevel = 0.005 // More noise
        detector.simulateFailures = true
        detector.failureProbability = 0.1 // 10% failure rate
        
        return detector
    }
}