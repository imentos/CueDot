import XCTest
@testable import CueDot
import simd

/// Comprehensive tests for ARFrameProvider functionality
/// Tests synthetic frame generation, camera transforms, and lighting simulation
@available(iOS 17.0, *)
class ARFrameProviderTests: XCTestCase {
    
    var frameProvider: ARFrameProvider!
    
    override func setUp() {
        super.setUp()
        frameProvider = ARFrameProvider()
    }
    
    override func tearDown() {
        frameProvider = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        XCTAssertEqual(frameProvider.configuration.targetFrameRate, 60)
        XCTAssertEqual(frameProvider.configuration.imageResolution.width, 1920, accuracy: 0.1)
        XCTAssertEqual(frameProvider.configuration.imageResolution.height, 1440, accuracy: 0.1)
        XCTAssertFalse(frameProvider.configuration.enableSyntheticDetections)
    }
    
    func testCustomConfiguration() {
        let config = ARFrameConfiguration(
            targetFrameRate: 30,
            imageResolution: CGSize(width: 1280, height: 720),
            cameraMotionPattern: .circular,
            enableSyntheticDetections: true,
            detectionCountRange: 1...5
        )
        
        let customProvider = ARFrameProvider(configuration: config)
        
        XCTAssertEqual(customProvider.configuration.targetFrameRate, 30)
        XCTAssertEqual(customProvider.configuration.imageResolution.width, 1280, accuracy: 0.1)
        XCTAssertTrue(customProvider.configuration.enableSyntheticDetections)
        XCTAssertEqual(customProvider.configuration.detectionCountRange, 1...5)
    }
    
    // MARK: - Frame Generation Tests
    
    func testBasicFrameGeneration() {
        let timestamp: TimeInterval = 1.0
        let cameraTransform = matrix_identity_float4x4
        let lighting: Float = 0.8
        let detections: [BallDetectionResult] = []
        
        let frame = frameProvider.generateFrame(
            timestamp: timestamp,
            cameraTransform: cameraTransform,
            lightingConditions: lighting,
            detections: detections
        )
        
        XCTAssertEqual(frame.timestamp, 1.0, accuracy: 0.001)
        XCTAssertEqual(frame.lightingConditions, 0.8, accuracy: 0.001)
        XCTAssertEqual(frame.detections.count, 0)
        XCTAssertEqual(frame.frameNumber, 1)
        
        // Verify transform matrix
        let identity = matrix_identity_float4x4
        for i in 0..<4 {
            for j in 0..<4 {
                XCTAssertEqual(frame.cameraTransform[i][j], identity[i][j], accuracy: 0.001)
            }
        }
    }
    
    func testFrameSequenceGeneration() {
        let frames = frameProvider.generateFrameSequence(
            count: 5,
            startTime: 0.0,
            frameInterval: 0.1
        )
        
        XCTAssertEqual(frames.count, 5)
        
        // Verify timestamps
        for (index, frame) in frames.enumerated() {
            let expectedTimestamp = Double(index) * 0.1
            XCTAssertEqual(frame.timestamp, expectedTimestamp, accuracy: 0.001)
            XCTAssertEqual(frame.frameNumber, UInt64(index + 1))
        }
    }
    
    func testFrameSequenceWithDefaultInterval() {
        let frames = frameProvider.generateFrameSequence(count: 3)
        
        XCTAssertEqual(frames.count, 3)
        
        // Should use default frame interval (1/60 = ~0.0167)
        let expectedInterval = 1.0 / 60.0
        XCTAssertEqual(frames[1].timestamp - frames[0].timestamp, expectedInterval, accuracy: 0.001)
        XCTAssertEqual(frames[2].timestamp - frames[1].timestamp, expectedInterval, accuracy: 0.001)
    }
    
    // MARK: - Camera Transform Tests
    
    func testStaticCameraTransform() {
        let config = ARFrameConfiguration(cameraMotionPattern: .staticCamera)
        let staticProvider = ARFrameProvider(configuration: config)
        
        let transform1 = staticProvider.generateCameraTransform(for: 0.0)
        let transform2 = staticProvider.generateCameraTransform(for: 1.0)
        
        // Static transforms should be identical
        for i in 0..<4 {
            for j in 0..<4 {
                XCTAssertEqual(transform1[i][j], transform2[i][j], accuracy: 0.001)
            }
        }
    }
    
    func testCircularCameraMotion() {
        let config = ARFrameConfiguration(
            cameraMotionPattern: .circular,
            motionSpeed: 1.0
        )
        let circularProvider = ARFrameProvider(configuration: config)
        
        let transform1 = circularProvider.generateCameraTransform(for: 0.0)
        let transform2 = circularProvider.generateCameraTransform(for: 1.0)
        
        // Transforms should be different
        let position1 = SIMD3<Float>(transform1.columns.3.x, transform1.columns.3.y, transform1.columns.3.z)
        let position2 = SIMD3<Float>(transform2.columns.3.x, transform2.columns.3.y, transform2.columns.3.z)
        
        let distance = length(position2 - position1)
        XCTAssertGreaterThan(distance, 0.1) // Should have moved significantly
        
        // Should be on a circle (constant distance from origin in XZ plane)
        let radius1 = sqrt(position1.x * position1.x + position1.z * position1.z)
        let radius2 = sqrt(position2.x * position2.x + position2.z * position2.z)
        XCTAssertEqual(radius1, radius2, accuracy: 0.01)
    }
    
    func testLinearCameraMotion() {
        let config = ARFrameConfiguration(
            cameraMotionPattern: .linear,
            motionSpeed: 2.0
        )
        let linearProvider = ARFrameProvider(configuration: config)
        
        let transform1 = linearProvider.generateCameraTransform(for: 0.0)
        let transform2 = linearProvider.generateCameraTransform(for: 1.0)
        
        let position1 = transform1.columns.3.x
        let position2 = transform2.columns.3.x
        
        // Should move linearly in X direction
        let expectedDistance = Float(2.0 * 1.0) // speed * time
        XCTAssertEqual(position2 - position1, expectedDistance, accuracy: 0.01)
        
        // Y should be constant
        XCTAssertEqual(transform1.columns.3.y, transform2.columns.3.y, accuracy: 0.01)
    }
    
    func testHandheldCameraMotion() {
        let config = ARFrameConfiguration(cameraMotionPattern: .handheld)
        let handheldProvider = ARFrameProvider(configuration: config)
        
        let transform1 = handheldProvider.generateCameraTransform(for: 0.0)
        let transform2 = handheldProvider.generateCameraTransform(for: 0.1)
        let transform3 = handheldProvider.generateCameraTransform(for: 0.2)
        
        // Should have subtle variations (handheld simulation)
        let pos1 = SIMD3<Float>(transform1.columns.3.x, transform1.columns.3.y, transform1.columns.3.z)
        let pos2 = SIMD3<Float>(transform2.columns.3.x, transform2.columns.3.y, transform2.columns.3.z)
        let pos3 = SIMD3<Float>(transform3.columns.3.x, transform3.columns.3.y, transform3.columns.3.z)
        
        // Should have movement but not too much
        let distance12 = length(pos2 - pos1)
        let distance23 = length(pos3 - pos2)
        
        XCTAssertGreaterThan(distance12, 0.0)
        XCTAssertLessThan(distance12, 1.0) // Not too much movement
        XCTAssertGreaterThan(distance23, 0.0)
        XCTAssertLessThan(distance23, 1.0)
    }
    
    func testCustomCameraMotion() {
        let customTransform = { (timestamp: TimeInterval) -> matrix_float4x4 in
            let x = Float(timestamp * 2.0)
            return matrix_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(x, 0, 0, 1)
            )
        }
        
        let config = ARFrameConfiguration(cameraMotionPattern: .custom(customTransform))
        let customProvider = ARFrameProvider(configuration: config)
        
        let transform = customProvider.generateCameraTransform(for: 1.5)
        let expectedX = Float(1.5 * 2.0)
        
        XCTAssertEqual(transform.columns.3.x, expectedX, accuracy: 0.001)
    }
    
    // MARK: - Camera Intrinsics Tests
    
    func testCameraIntrinsics() {
        let intrinsics = frameProvider.generateCameraIntrinsics()
        
        // Should be a 3x3 matrix
        XCTAssertEqual(intrinsics[2][2], 1.0, accuracy: 0.001) // Bottom-right should be 1
        
        // Focal lengths should be reasonable
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        XCTAssertGreaterThan(fx, 100.0)
        XCTAssertGreaterThan(fy, 100.0)
        
        // Principal point should be roughly center
        let cx = intrinsics[0][2]
        let cy = intrinsics[1][2]
        let expectedCx = Float(frameProvider.configuration.imageResolution.width) * 0.5
        let expectedCy = Float(frameProvider.configuration.imageResolution.height) * 0.5
        
        XCTAssertEqual(cx, expectedCx, accuracy: 1.0)
        XCTAssertEqual(cy, expectedCy, accuracy: 1.0)
    }
    
    func testIntrinsicsCaching() {
        let intrinsics1 = frameProvider.generateCameraIntrinsics()
        let intrinsics2 = frameProvider.generateCameraIntrinsics()
        
        // Should be identical (cached)
        for i in 0..<3 {
            for j in 0..<3 {
                XCTAssertEqual(intrinsics1[i][j], intrinsics2[i][j], accuracy: 0.001)
            }
        }
    }
    
    // MARK: - Lighting Simulation Tests
    
    func testConstantLighting() {
        let config = ARFrameConfiguration(lightingPattern: .constant(0.6))
        let provider = ARFrameProvider(configuration: config)
        
        let lighting1 = provider.generateLightingConditions(for: 0.0)
        let lighting2 = provider.generateLightingConditions(for: 5.0)
        
        XCTAssertEqual(lighting1, 0.6, accuracy: 0.001)
        XCTAssertEqual(lighting2, 0.6, accuracy: 0.001)
    }
    
    func testDynamicLighting() {
        let config = ARFrameConfiguration(lightingPattern: .dynamic)
        let provider = ARFrameProvider(configuration: config)
        
        let lighting1 = provider.generateLightingConditions(for: 0.0)
        let lighting2 = provider.generateLightingConditions(for: 1.0)
        let lighting3 = provider.generateLightingConditions(for: 2.0)
        
        // Should be within valid range
        XCTAssertGreaterThanOrEqual(lighting1, 0.0)
        XCTAssertLessThanOrEqual(lighting1, 1.0)
        XCTAssertGreaterThanOrEqual(lighting2, 0.0)
        XCTAssertLessThanOrEqual(lighting2, 1.0)
        XCTAssertGreaterThanOrEqual(lighting3, 0.0)
        XCTAssertLessThanOrEqual(lighting3, 1.0)
        
        // Should vary over time
        XCTAssertNotEqual(lighting1, lighting2, accuracy: 0.01)
    }
    
    func testFlickeringLighting() {
        let config = ARFrameConfiguration(lightingPattern: .flickering)
        let provider = ARFrameProvider(configuration: config)
        
        var lightingValues: [Float] = []
        for i in 0..<100 {
            let timestamp = Double(i) * 0.01
            let lighting = provider.generateLightingConditions(for: timestamp)
            lightingValues.append(lighting)
        }
        
        // Should have significant variance (flickering)
        let mean = lightingValues.reduce(0.0, +) / Float(lightingValues.count)
        let variance = lightingValues.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(lightingValues.count)
        let standardDeviation = sqrt(variance)
        
        XCTAssertGreaterThan(standardDeviation, 0.1) // Should have significant variation
    }
    
    func testCustomLighting() {
        let customLighting = { (timestamp: TimeInterval) -> Float in
            return Float(sin(timestamp) * 0.5 + 0.5) // Sine wave 0-1
        }
        
        let config = ARFrameConfiguration(lightingPattern: .custom(customLighting))
        let provider = ARFrameProvider(configuration: config)
        
        let lighting = provider.generateLightingConditions(for: .pi / 2) // Sin(π/2) = 1
        XCTAssertEqual(lighting, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Synthetic Detection Tests
    
    func testSyntheticDetectionDisabled() {
        let config = ARFrameConfiguration(enableSyntheticDetections: false)
        let provider = ARFrameProvider(configuration: config)
        
        let detections = provider.generateSyntheticDetections(for: 1.0)
        XCTAssertEqual(detections.count, 0)
    }
    
    func testSyntheticDetectionEnabled() {
        let config = ARFrameConfiguration(
            enableSyntheticDetections: true,
            detectionCountRange: 2...4
        )
        let provider = ARFrameProvider(configuration: config)
        
        let detections = provider.generateSyntheticDetections(for: 1.0)
        XCTAssertGreaterThanOrEqual(detections.count, 2)
        XCTAssertLessThanOrEqual(detections.count, 4)
        
        // Check detection properties
        for detection in detections {
            XCTAssertGreaterThan(detection.confidence, 0.0)
            XCTAssertLessThan(detection.confidence, 1.0)
            XCTAssertEqual(detection.timestamp, 1.0, accuracy: 0.001)
        }
    }
    
    func testSyntheticDetectionBounds() {
        let bounds: (x: ClosedRange<Float>, y: ClosedRange<Float>, z: ClosedRange<Float>) = (
            x: -1.0...1.0,
            y: -0.5...0.5,
            z: -2.0...2.0
        )
        
        let config = ARFrameConfiguration(
            enableSyntheticDetections: true,
            detectionCountRange: 10...10, // Fixed count for testing
            detectionBounds: bounds
        )
        let provider = ARFrameProvider(configuration: config)
        
        let detections = provider.generateSyntheticDetections(for: 1.0)
        XCTAssertEqual(detections.count, 10)
        
        // Verify all detections are within bounds
        for detection in detections {
            XCTAssertGreaterThanOrEqual(detection.ballCenter3D.x, bounds.x.lowerBound)
            XCTAssertLessThanOrEqual(detection.ballCenter3D.x, bounds.x.upperBound)
            XCTAssertGreaterThanOrEqual(detection.ballCenter3D.y, bounds.y.lowerBound)
            XCTAssertLessThanOrEqual(detection.ballCenter3D.y, bounds.y.upperBound)
            XCTAssertGreaterThanOrEqual(detection.ballCenter3D.z, bounds.z.lowerBound)
            XCTAssertLessThanOrEqual(detection.ballCenter3D.z, bounds.z.upperBound)
        }
    }
    
    func testSingleDetectionGeneration() {
        let detection = frameProvider.generateSingleDetection(index: 0, timestamp: 2.5)
        
        XCTAssertEqual(detection.timestamp, 2.5, accuracy: 0.001)
        XCTAssertGreaterThan(detection.confidence, 0.0)
        XCTAssertLessThan(detection.confidence, 1.0)
        
        // Position should be within default bounds
        XCTAssertGreaterThanOrEqual(detection.ballCenter3D.x, -3.0)
        XCTAssertLessThanOrEqual(detection.ballCenter3D.x, 3.0)
        XCTAssertGreaterThanOrEqual(detection.ballCenter3D.y, -1.5)
        XCTAssertLessThanOrEqual(detection.ballCenter3D.y, 1.5)
        XCTAssertGreaterThanOrEqual(detection.ballCenter3D.z, -5.0)
        XCTAssertLessThanOrEqual(detection.ballCenter3D.z, 5.0)
    }
    
    // MARK: - Test Data Generation Tests
    
    func testPerformanceTestData() {
        let duration: TimeInterval = 1.0
        let targetFPS = 30
        
        let frames = frameProvider.generatePerformanceTestData(
            duration: duration,
            targetFPS: targetFPS
        )
        
        XCTAssertEqual(frames.count, 30) // 1 second * 30 FPS
        
        // Verify timing
        let expectedInterval = 1.0 / Double(targetFPS)
        for i in 1..<frames.count {
            let actualInterval = frames[i].timestamp - frames[i-1].timestamp
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 0.001)
        }
    }
    
    func testStressTestData() {
        let frameCount = 5
        let maxDetections = 8
        
        let frames = frameProvider.generateStressTestData(
            frameCount: frameCount,
            maxDetections: maxDetections
        )
        
        XCTAssertEqual(frames.count, frameCount)
        
        // Should have high detection counts
        for frame in frames {
            XCTAssertGreaterThanOrEqual(frame.detections.count, 5)
            XCTAssertLessThanOrEqual(frame.detections.count, maxDetections)
        }
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Generate some frames to increment counter
        let _ = frameProvider.generateFrameSequence(count: 3)
        
        frameProvider.reset()
        
        // Next frame should have frameNumber 1
        let frame = frameProvider.generateFrame(
            timestamp: 0.0,
            cameraTransform: matrix_identity_float4x4,
            lightingConditions: 0.5,
            detections: []
        )
        
        XCTAssertEqual(frame.frameNumber, 1)
    }
    
    // MARK: - Performance Tests
    
    func testFrameGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = frameProvider.generateFrame(
                    timestamp: Double.random(in: 0.0...10.0),
                    cameraTransform: matrix_identity_float4x4,
                    lightingConditions: Float.random(in: 0.0...1.0),
                    detections: []
                )
            }
        }
    }
    
    func testCameraTransformPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = frameProvider.generateCameraTransform(for: Double(i) * 0.1)
            }
        }
    }
    
    func testSyntheticDetectionPerformance() {
        let config = ARFrameConfiguration(
            enableSyntheticDetections: true,
            detectionCountRange: 1...5
        )
        let provider = ARFrameProvider(configuration: config)
        
        measure {
            for i in 0..<100 {
                let _ = provider.generateSyntheticDetections(for: Double(i) * 0.1)
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testZeroTimestamp() {
        let frame = frameProvider.generateFrame(
            timestamp: 0.0,
            cameraTransform: matrix_identity_float4x4,
            lightingConditions: 0.5,
            detections: []
        )
        
        XCTAssertEqual(frame.timestamp, 0.0, accuracy: 0.001)
    }
    
    func testNegativeTimestamp() {
        let frame = frameProvider.generateFrame(
            timestamp: -1.0,
            cameraTransform: matrix_identity_float4x4,
            lightingConditions: 0.5,
            detections: []
        )
        
        XCTAssertEqual(frame.timestamp, -1.0, accuracy: 0.001)
    }
    
    func testLargeTimestamp() {
        let largeTimestamp = 1000000.0
        let lighting = frameProvider.generateLightingConditions(for: largeTimestamp)
        
        // Should handle large values without crashing
        XCTAssertGreaterThanOrEqual(lighting, 0.0)
        XCTAssertLessThanOrEqual(lighting, 1.0)
    }
    
    func testEmptySequence() {
        let frames = frameProvider.generateFrameSequence(count: 0)
        XCTAssertEqual(frames.count, 0)
    }
    
    func testSingleFrameSequence() {
        let frames = frameProvider.generateFrameSequence(count: 1)
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].frameNumber, 1)
    }
}