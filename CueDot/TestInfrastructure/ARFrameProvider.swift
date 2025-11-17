import Foundation
import simd
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Utility for generating synthetic AR frame data for testing
/// Provides realistic camera matrices, lighting simulation, and frame timing
@available(iOS 17.0, *)
public class ARFrameProvider {
    
    // MARK: - Configuration
    
    /// Configuration for frame generation
    public let configuration: ARFrameConfiguration
    
    // MARK: - Internal State
    
    /// Frame counter for unique frame identification
    private var frameCounter: UInt64 = 0
    
    /// Random number generator for consistent test results
    private var randomGenerator = SystemRandomNumberGenerator()
    
    /// Camera intrinsics cache
    private var cachedIntrinsics: matrix_float3x3?
    
    /// Previous frame timestamp for delta calculations
    private var previousTimestamp: TimeInterval = 0.0
    
    // MARK: - Initialization
    
    /// Initialize with configuration
    /// - Parameter configuration: Frame generation configuration
    public init(configuration: ARFrameConfiguration = ARFrameConfiguration()) {
        self.configuration = configuration
        setupCameraIntrinsics()
    }
    
    // MARK: - Frame Generation
    
    /// Generate a synthetic AR frame
    /// - Parameters:
    ///   - timestamp: Frame timestamp
    ///   - cameraTransform: Camera transform matrix
    ///   - lightingConditions: Lighting intensity (0.0 to 1.0)
    ///   - detections: Ball detection results for this frame
    /// - Returns: Mock AR frame with synthetic data
    public func generateFrame(
        timestamp: TimeInterval,
        cameraTransform: matrix_float4x4,
        lightingConditions: Float,
        detections: [BallDetectionResult]
    ) -> MockARFrame {
        frameCounter += 1
        
        return MockARFrame(
            timestamp: timestamp,
            cameraTransform: cameraTransform,
            lightingConditions: lightingConditions,
            detections: detections,
            frameNumber: frameCounter
        )
    }
    
    /// Generate a sequence of frames for testing
    /// - Parameters:
    ///   - count: Number of frames to generate
    ///   - startTime: Starting timestamp
    ///   - frameInterval: Time between frames
    /// - Returns: Array of mock AR frames
    public func generateFrameSequence(
        count: Int,
        startTime: TimeInterval = 0.0,
        frameInterval: TimeInterval? = nil
    ) -> [MockARFrame] {
        let interval = frameInterval ?? (1.0 / Double(configuration.targetFrameRate))
        var frames: [MockARFrame] = []
        
        for i in 0..<count {
            let timestamp = startTime + (Double(i) * interval)
            let cameraTransform = generateCameraTransform(for: timestamp)
            let lighting = generateLightingConditions(for: timestamp)
            let detections = generateSyntheticDetections(for: timestamp)
            
            let frame = generateFrame(
                timestamp: timestamp,
                cameraTransform: cameraTransform,
                lightingConditions: lighting,
                detections: detections
            )
            frames.append(frame)
        }
        
        return frames
    }
    
    // MARK: - Camera Transform Generation
    
    /// Generate realistic camera transform for given timestamp
    /// - Parameter timestamp: Frame timestamp
    /// - Returns: 4x4 transform matrix
    public func generateCameraTransform(for timestamp: TimeInterval) -> matrix_float4x4 {
        switch configuration.cameraMotionPattern {
        case .staticCamera:
            return generateStaticTransform()
        case .circular:
            return generateCircularMotion(timestamp: timestamp)
        case .linear:
            return generateLinearMotion(timestamp: timestamp)
        case .handheld:
            return generateHandheldMotion(timestamp: timestamp)
        case .custom(let provider):
            return provider(timestamp)
        }
    }
    
    /// Generate camera intrinsics matrix
    /// - Returns: 3x3 camera intrinsics matrix
    public func generateCameraIntrinsics() -> matrix_float3x3 {
        if let cached = cachedIntrinsics {
            return cached
        }
        
        let fx = Float(configuration.imageResolution.width) * 0.8  // Typical focal length
        let fy = Float(configuration.imageResolution.height) * 0.8
        let cx = Float(configuration.imageResolution.width) * 0.5   // Principal point
        let cy = Float(configuration.imageResolution.height) * 0.5
        
        let intrinsics = matrix_float3x3(
            SIMD3<Float>(fx, 0, cx),
            SIMD3<Float>(0, fy, cy),
            SIMD3<Float>(0, 0, 1)
        )
        
        cachedIntrinsics = intrinsics
        return intrinsics
    }
    
    // MARK: - Lighting Simulation
    
    /// Generate realistic lighting conditions
    /// - Parameter timestamp: Frame timestamp
    /// - Returns: Lighting intensity from 0.0 to 1.0
    public func generateLightingConditions(for timestamp: TimeInterval) -> Float {
        switch configuration.lightingPattern {
        case .constant(let intensity):
            return intensity
        case .dynamic:
            return generateDynamicLighting(timestamp: timestamp)
        case .flickering:
            return generateFlickeringLighting(timestamp: timestamp)
        case .custom(let provider):
            return provider(timestamp)
        }
    }
    
    // MARK: - Detection Generation
    
    /// Generate synthetic ball detections for testing
    /// - Parameter timestamp: Frame timestamp
    /// - Returns: Array of synthetic ball detection results
    public func generateSyntheticDetections(for timestamp: TimeInterval) -> [BallDetectionResult] {
        guard configuration.enableSyntheticDetections else { return [] }
        
        let detectionCount = Int.random(in: configuration.detectionCountRange)
        var detections: [BallDetectionResult] = []
        
        for i in 0..<detectionCount {
            let detection = generateSingleDetection(index: i, timestamp: timestamp)
            detections.append(detection)
        }
        
        return detections
    }
    
    /// Generate a single synthetic ball detection
    /// - Parameters:
    ///   - index: Detection index within the frame
    ///   - timestamp: Frame timestamp
    /// - Returns: Synthetic ball detection result
    public func generateSingleDetection(index: Int, timestamp: TimeInterval) -> BallDetectionResult {
        // Generate position within realistic bounds
        let position = SIMD3<Float>(
            Float.random(in: configuration.detectionBounds.x),
            Float.random(in: configuration.detectionBounds.y),
            Float.random(in: configuration.detectionBounds.z)
        )
        
        // Generate confidence based on distance and lighting
        let distance = length(position)
        let distanceFactor = 1.0 - min(distance / 10.0, 0.8) // Closer = higher confidence
        let lightingFactor = generateLightingConditions(for: timestamp)
        let baseConfidence = distanceFactor * lightingFactor
        
        // Add some randomness
        let confidenceNoise = Float.random(in: -0.1...0.1)
        let finalConfidence = max(0.1, min(0.98, baseConfidence + confidenceNoise))
        
        return BallDetectionResult(
            ballCenter3D: position,
            confidence: finalConfidence,
            timestamp: timestamp,
            isOccluded: Bool.random() && finalConfidence < 0.7,
            hasMultipleBalls: index > 0 && Bool.random()
        )
    }
    
    // MARK: - Test Data Utilities
    
    /// Generate test data for performance benchmarking
    /// - Parameters:
    ///   - duration: Test duration in seconds
    ///   - targetFPS: Target frame rate
    /// - Returns: Performance test frame sequence
    public func generatePerformanceTestData(
        duration: TimeInterval,
        targetFPS: Int = 60
    ) -> [MockARFrame] {
        let frameCount = Int(duration * Double(targetFPS))
        let interval = 1.0 / Double(targetFPS)
        
        return generateFrameSequence(
            count: frameCount,
            startTime: 0.0,
            frameInterval: interval
        )
    }
    
    /// Generate stress test data with high detection counts
    /// - Parameters:
    ///   - frameCount: Number of frames to generate
    ///   - maxDetections: Maximum detections per frame
    /// - Returns: Stress test frame sequence
    public func generateStressTestData(
        frameCount: Int,
        maxDetections: Int = 10
    ) -> [MockARFrame] {
        var config = configuration
        config.detectionCountRange = 5...maxDetections
        config.enableSyntheticDetections = true
        
        let tempProvider = ARFrameProvider(configuration: config)
        return tempProvider.generateFrameSequence(count: frameCount)
    }
    
    /// Reset frame counter and state
    public func reset() {
        frameCounter = 0
        previousTimestamp = 0.0
        cachedIntrinsics = nil
    }
    
    // MARK: - Private Camera Motion Methods
    
    private func generateStaticTransform() -> matrix_float4x4 {
        return matrix_identity_float4x4
    }
    
    private func generateCircularMotion(timestamp: TimeInterval) -> matrix_float4x4 {
        let radius: Float = 2.0
        let speed = configuration.motionSpeed
        let angle = Float(timestamp * speed)
        
        let x = cos(angle) * radius
        let z = sin(angle) * radius
        let y: Float = 0.5
        
        let translation = matrix4x4_translation(x, y, z)
        
        // Look towards center
        let lookDirection = normalize(SIMD3<Float>(-x, 0, -z))
        let rotation = matrix4x4_lookAt(direction: lookDirection)
        
        return matrix_multiply(translation, rotation)
    }
    
    private func generateLinearMotion(timestamp: TimeInterval) -> matrix_float4x4 {
        let speed = configuration.motionSpeed
        let distance = Float(timestamp * speed)
        
        let x = distance
        let y: Float = 1.0
        let z: Float = 0.0
        
        return matrix4x4_translation(x, y, z)
    }
    
    private func generateHandheldMotion(timestamp: TimeInterval) -> matrix_float4x4 {
        let time = Float(timestamp)
        
        // Simulate hand tremor and movement
        let baseX = sin(time * 0.5) * 0.1
        let baseY = 1.0 + cos(time * 0.3) * 0.05
        let baseZ = cos(time * 0.4) * 0.2
        
        // Add high-frequency shake
        let shakeIntensity: Float = 0.002
        let shakeX = sin(time * 50.0) * shakeIntensity
        let shakeY = cos(time * 30.0) * shakeIntensity
        let shakeZ = sin(time * 40.0) * shakeIntensity
        
        let finalX = baseX + shakeX
        let finalY = baseY + shakeY
        let finalZ = baseZ + shakeZ
        
        // Add slight rotation variations
        let rotationX = sin(time * 0.7) * 0.01
        let rotationY = cos(time * 0.8) * 0.015
        let rotationZ = sin(time * 0.6) * 0.005
        
        let translation = matrix4x4_translation(finalX, finalY, finalZ)
        let rotation = matrix4x4_rotation(rotationX, rotationY, rotationZ)
        
        return matrix_multiply(translation, rotation)
    }
    
    // MARK: - Private Lighting Methods
    
    private func generateDynamicLighting(timestamp: TimeInterval) -> Float {
        let time = Float(timestamp)
        let base = 0.5 + sin(time * 0.2) * 0.3  // Slow brightness variation
        let flicker = sin(time * 10.0) * 0.05    // Fast flicker
        return max(0.1, min(1.0, base + flicker))
    }
    
    private func generateFlickeringLighting(timestamp: TimeInterval) -> Float {
        let time = Float(timestamp)
        let base: Float = 0.7
        let flicker = sin(time * 25.0) * 0.4  // Intense flickering
        return max(0.1, min(1.0, base + flicker))
    }
    
    // MARK: - Private Setup Methods
    
    private func setupCameraIntrinsics() {
        // Cache intrinsics on initialization
        _ = generateCameraIntrinsics()
    }
}

// MARK: - Configuration

/// Configuration for AR frame generation
public struct ARFrameConfiguration {
    /// Target frame rate for generation
    public var targetFrameRate: Int
    
    /// Image resolution for camera intrinsics
    public var imageResolution: CGSize
    
    /// Camera motion pattern
    public var cameraMotionPattern: CameraMotionPattern
    
    /// Motion speed multiplier
    public var motionSpeed: Double
    
    /// Lighting simulation pattern
    public var lightingPattern: LightingPattern
    
    /// Whether to generate synthetic detections
    public var enableSyntheticDetections: Bool
    
    /// Range for number of detections per frame
    public var detectionCountRange: ClosedRange<Int>
    
    /// 3D bounds for detection generation
    public var detectionBounds: (x: ClosedRange<Float>, y: ClosedRange<Float>, z: ClosedRange<Float>)
    
    public init(
        targetFrameRate: Int = 60,
        imageResolution: CGSize = CGSize(width: 1920, height: 1440),
        cameraMotionPattern: CameraMotionPattern = .handheld,
        motionSpeed: Double = 1.0,
        lightingPattern: LightingPattern = .dynamic,
        enableSyntheticDetections: Bool = false,
        detectionCountRange: ClosedRange<Int> = 0...3,
        detectionBounds: (x: ClosedRange<Float>, y: ClosedRange<Float>, z: ClosedRange<Float>) = (
            x: -3.0...3.0,
            y: -1.5...1.5,
            z: -5.0...5.0
        )
    ) {
        self.targetFrameRate = targetFrameRate
        self.imageResolution = imageResolution
        self.cameraMotionPattern = cameraMotionPattern
        self.motionSpeed = motionSpeed
        self.lightingPattern = lightingPattern
        self.enableSyntheticDetections = enableSyntheticDetections
        self.detectionCountRange = detectionCountRange
        self.detectionBounds = detectionBounds
    }
}

// MARK: - Motion Patterns

/// Camera motion patterns for testing
public enum CameraMotionPattern {
    case staticCamera
    case circular
    case linear
    case handheld
    case custom((TimeInterval) -> matrix_float4x4)
}

/// Lighting simulation patterns
public enum LightingPattern {
    case constant(Float)
    case dynamic
    case flickering
    case custom((TimeInterval) -> Float)
}

// MARK: - Matrix Utilities

private func matrix4x4_translation(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
    return matrix_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(x, y, z, 1)
    )
}

private func matrix4x4_rotation(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
    let cx = cos(x), sx = sin(x)
    let cy = cos(y), sy = sin(y)
    let cz = cos(z), sz = sin(z)
    
    let rotX = matrix_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, cx, -sx, 0),
        SIMD4<Float>(0, sx, cx, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
    
    let rotY = matrix_float4x4(
        SIMD4<Float>(cy, 0, sy, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(-sy, 0, cy, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
    
    let rotZ = matrix_float4x4(
        SIMD4<Float>(cz, -sz, 0, 0),
        SIMD4<Float>(sz, cz, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
    
    return matrix_multiply(matrix_multiply(rotZ, rotY), rotX)
}

private func matrix4x4_lookAt(direction: SIMD3<Float>) -> matrix_float4x4 {
    let forward = normalize(direction)
    let up = SIMD3<Float>(0, 1, 0)
    let right = normalize(cross(forward, up))
    let actualUp = cross(right, forward)
    
    return matrix_float4x4(
        SIMD4<Float>(right.x, actualUp.x, -forward.x, 0),
        SIMD4<Float>(right.y, actualUp.y, -forward.y, 0),
        SIMD4<Float>(right.z, actualUp.z, -forward.z, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}