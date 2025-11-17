import XCTest
import simd
#if canImport(ARKit)
import ARKit
#endif
@testable import CueDot

/// Integration tests for AR Ball Detection system
/// Tests the complete pipeline from 2D detection to 3D positioning
@available(iOS 13.0, *)
final class ARBallDetectionIntegrationTests: XCTestCase {
    
    // MARK: - Test Setup
    
    var arDetectionIntegrator: ARBallDetectionIntegrator!
    var testARFrameGenerator: TestARFrameGenerator!
    var coordinateTransform: ARCoordinateTransform!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        arDetectionIntegrator = ARBallDetectionIntegrator()
        testARFrameGenerator = TestARFrameGenerator()
        coordinateTransform = ARCoordinateTransform()
    }
    
    override func tearDownWithError() throws {
        arDetectionIntegrator = nil
        testARFrameGenerator = nil
        coordinateTransform = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic AR Integration Tests
    
    func testBasic3DBallDetection() throws {
        let expectation = XCTestExpectation(description: "Basic 3D ball detection")
        
        // Create test setup with known camera position and ball
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        let testImage = testARFrameGenerator.generateImageWithBall(
            ballPosition3D: simd_float3(0, 0, -1), // 1 meter in front of camera
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            XCTAssertGreaterThan(result.detections3D.count, 0, "Should detect at least one ball in 3D")
            
            if let detection = result.detections3D.first {
                // Verify 3D position is reasonable
                XCTAssertGreaterThan(detection.worldPosition.z, -2.0, "Ball should be in front of camera")
                XCTAssertLessThan(detection.worldPosition.z, 0.0, "Ball should be in negative Z (camera forward)")
                
                // Verify depth estimation
                XCTAssertGreaterThan(detection.estimatedDepth, 0.5, "Depth should be reasonable")
                XCTAssertLessThan(detection.estimatedDepth, 2.0, "Depth should not be too far")
                
                // Verify confidence
                XCTAssertGreaterThan(detection.confidence, 0.3, "Should have reasonable confidence")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultiple3DBallDetection() throws {
        let expectation = XCTestExpectation(description: "Multiple 3D ball detection")
        
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        
        let ballPositions = [
            simd_float3(-0.5, 0, -1.0),  // Left ball
            simd_float3(0.0, 0, -1.2),   // Center ball
            simd_float3(0.5, 0, -0.8)    // Right ball
        ]
        
        let testImage = testARFrameGenerator.generateImageWithMultipleBalls(
            ballPositions3D: ballPositions,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            XCTAssertGreaterThanOrEqual(result.detections3D.count, 2, "Should detect multiple balls in 3D")
            
            // Verify balls are spatially separated
            let positions = result.detections3D.map { $0.worldPosition }
            for i in 0..<positions.count {
                for j in (i+1)..<positions.count {
                    let distance = simd_length(positions[i] - positions[j])
                    XCTAssertGreaterThan(distance, 0.1, "Balls should be spatially separated")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Coordinate System Tests
    
    func testWorldToScreenProjection() throws {
        let worldPosition = simd_float3(0, 0, -1) // 1 meter in front
        let cameraTransform = matrix_identity_float4x4
        let viewportSize = CGSize(width: 640, height: 480)
        let intrinsics = createTestCameraIntrinsics()
        
        coordinateTransform.updateMatrices(
            cameraTransform: cameraTransform,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: viewportSize,
            intrinsics: intrinsics
        )
        
        let screenPoint = coordinateTransform.worldToScreen(worldPosition)
        XCTAssertNotNil(screenPoint, "Should be able to project world point to screen")
        
        if let point = screenPoint {
            // Point should be near screen center
            XCTAssertGreaterThan(point.x, 200, "X should be in reasonable screen range")
            XCTAssertLessThan(point.x, 440, "X should be in reasonable screen range")
            XCTAssertGreaterThan(point.y, 150, "Y should be in reasonable screen range")
            XCTAssertLessThan(point.y, 330, "Y should be in reasonable screen range")
        }
    }
    
    func testScreenToWorldRay() throws {
        let screenPoint = CGPoint(x: 320, y: 240) // Screen center
        let viewportSize = CGSize(width: 640, height: 480)
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        
        coordinateTransform.updateMatrices(
            cameraTransform: cameraTransform,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: viewportSize,
            intrinsics: intrinsics
        )
        
        let (rayOrigin, rayDirection) = coordinateTransform.screenToWorldRay(screenPoint)
        
        // Ray origin should be at camera position (0,0,0)
        XCTAssertEqual(rayOrigin.x, 0, accuracy: 0.001, "Ray origin X should be at camera")
        XCTAssertEqual(rayOrigin.y, 0, accuracy: 0.001, "Ray origin Y should be at camera")
        XCTAssertEqual(rayOrigin.z, 0, accuracy: 0.001, "Ray origin Z should be at camera")
        
        // Ray direction should point forward (negative Z)
        XCTAssertLessThan(rayDirection.z, 0, "Ray should point forward (negative Z)")
        XCTAssertEqual(simd_length(rayDirection), 1.0, accuracy: 0.001, "Ray direction should be normalized")
    }
    
    // MARK: - Depth Estimation Tests
    
    func testDepthEstimationAccuracy() throws {
        let expectation = XCTestExpectation(description: "Depth estimation accuracy")
        
        // Test with known ball at specific distance
        let trueBallPosition = simd_float3(0, 0, -1.5) // 1.5 meters away
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        
        let testImage = testARFrameGenerator.generateImageWithBall(
            ballPosition3D: trueBallPosition,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            XCTAssertGreaterThan(result.detections3D.count, 0, "Should detect ball")
            
            if let detection = result.detections3D.first {
                let estimatedDistance = simd_length(detection.worldPosition)
                let trueDistance = simd_length(trueBallPosition)
                let error = abs(estimatedDistance - trueDistance)
                
                // Depth estimation should be within reasonable error bounds
                XCTAssertLessThan(error, 0.3, "Depth estimation error should be < 30cm")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDepthEstimationWithTableConstraints() throws {
        let expectation = XCTestExpectation(description: "Depth estimation with table constraints")
        
        // Set up table information
        let tableCenter = simd_float3(0, -0.5, -1) // Table 50cm below camera
        let tableHeight: Float = -0.5
        let tableNormal = simd_float3(0, 1, 0)
        
        arDetectionIntegrator.updateTableInfo(
            center: tableCenter,
            height: tableHeight,
            normal: tableNormal,
            confidence: 0.8
        )
        
        // Ball on the table
        let ballPosition = simd_float3(0.3, -0.5, -1.2)
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        
        let testImage = testARFrameGenerator.generateImageWithBall(
            ballPosition3D: ballPosition,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            XCTAssertGreaterThan(result.detections3D.count, 0, "Should detect ball on table")
            
            if let detection = result.detections3D.first {
                // Ball should be constrained to table height
                XCTAssertEqual(detection.worldPosition.y, tableHeight, accuracy: 0.1, "Ball should be on table")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Temporal Tracking Tests
    
    func testTemporalBallTracking() throws {
        let expectation = XCTestExpectation(description: "Temporal ball tracking")
        expectation.expectedFulfillmentCount = 3
        
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        
        // Simulate ball moving across frames
        let ballPositions = [
            simd_float3(-0.2, 0, -1.0),
            simd_float3(0.0, 0, -1.0),
            simd_float3(0.2, 0, -1.0)
        ]
        
        var trackIds: [Int] = []
        
        for (index, position) in ballPositions.enumerated() {
            let testImage = testARFrameGenerator.generateImageWithBall(
                ballPosition3D: position,
                cameraTransform: cameraTransform,
                intrinsics: intrinsics
            )
            
            let timestamp = Date().timeIntervalSince1970 + Double(index) * 0.1
            
            arDetectionIntegrator.detectBallsWithManualAR(
                pixelBuffer: testImage.pixelBuffer,
                imageSize: testImage.imageSize,
                cameraTransform: cameraTransform,
                intrinsics: intrinsics,
                timestamp: timestamp
            ) { result in
                
                XCTAssertGreaterThan(result.detections3D.count, 0, "Should track ball across frames")
                
                if let detection = result.detections3D.first {
                    trackIds.append(detection.trackId)
                }
                
                // Check temporal consistency for later frames
                if index > 0 {
                    XCTAssertEqual(trackIds[index], trackIds[0], "Should maintain same track ID")
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Performance Tests
    
    func test3DDetectionPerformance() throws {
        let expectation = XCTestExpectation(description: "3D detection performance")
        expectation.expectedFulfillmentCount = 10
        
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        let ballPositions = [
            simd_float3(-0.5, 0, -1.0),
            simd_float3(0.0, 0, -1.2),
            simd_float3(0.5, 0, -0.8),
            simd_float3(-0.3, 0.2, -1.1),
            simd_float3(0.3, -0.2, -0.9)
        ]
        
        let testImage = testARFrameGenerator.generateImageWithMultipleBalls(
            ballPositions3D: ballPositions,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        var processingTimes: [TimeInterval] = []
        
        for i in 0..<10 {
            let startTime = Date()
            
            arDetectionIntegrator.detectBallsWithManualAR(
                pixelBuffer: testImage.pixelBuffer,
                imageSize: testImage.imageSize,
                cameraTransform: cameraTransform,
                intrinsics: intrinsics,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            ) { result in
                
                let processingTime = Date().timeIntervalSince(startTime)
                processingTimes.append(processingTime)
                
                XCTAssertGreaterThan(result.detections3D.count, 0, "Should maintain performance with multiple balls")
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Analyze performance
        let averageTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxTime = processingTimes.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.3, "Average 3D detection time should be under 300ms")
        XCTAssertLessThan(maxTime, 0.5, "Maximum 3D detection time should be under 500ms")
        
        print("3D Detection Performance Results:")
        print("Average processing time: \(averageTime * 1000)ms")
        print("Maximum processing time: \(maxTime * 1000)ms")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCameraTransform() throws {
        let expectation = XCTestExpectation(description: "Invalid camera transform handling")
        
        // Create invalid transform (all zeros)
        var invalidTransform = matrix_identity_float4x4
        invalidTransform.columns.0 = simd_float4(0, 0, 0, 0)
        
        let intrinsics = createTestCameraIntrinsics()
        let testImage = testARFrameGenerator.generateImageWithBall(
            ballPosition3D: simd_float3(0, 0, -1),
            cameraTransform: matrix_identity_float4x4, // Valid for image generation
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: invalidTransform, // Invalid for processing
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            // Should handle gracefully, possibly with no detections or low confidence
            // The exact behavior depends on implementation, but should not crash
            XCTAssertNotNil(result, "Should return a result even with invalid transform")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDetectionAtExtremeAngles() throws {
        let expectation = XCTestExpectation(description: "Detection at extreme camera angles")
        
        // Create camera transform with extreme rotation
        let rotationAngle: Float = .pi / 3 // 60 degrees
        var cameraTransform = matrix_identity_float4x4
        cameraTransform.columns.0 = simd_float4(cos(rotationAngle), 0, sin(rotationAngle), 0)
        cameraTransform.columns.2 = simd_float4(-sin(rotationAngle), 0, cos(rotationAngle), 0)
        
        let intrinsics = createTestCameraIntrinsics()
        let ballPosition = simd_float3(0, 0, -1)
        
        let testImage = testARFrameGenerator.generateImageWithBall(
            ballPosition3D: ballPosition,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            // Should handle extreme angles gracefully
            XCTAssertNotNil(result, "Should handle extreme camera angles")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Reset Tests
    
    func testSystemReset() throws {
        let expectation = XCTestExpectation(description: "System reset")
        
        // Perform some detections to build up state
        let cameraTransform = matrix_identity_float4x4
        let intrinsics = createTestCameraIntrinsics()
        let testImage = testARFrameGenerator.generateImageWithBall(
            ballPosition3D: simd_float3(0, 0, -1),
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
        
        arDetectionIntegrator.detectBallsWithManualAR(
            pixelBuffer: testImage.pixelBuffer,
            imageSize: testImage.imageSize,
            cameraTransform: cameraTransform,
            intrinsics: intrinsics,
            timestamp: Date().timeIntervalSince1970
        ) { result in
            
            // Reset the system
            self.arDetectionIntegrator.reset()
            
            // Verify reset by checking detection count
            XCTAssertEqual(self.arDetectionIntegrator.currentDetectionCount, 0, "Detection count should reset to 0")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestCameraIntrinsics() -> simd_float3x3 {
        // Typical smartphone camera intrinsics
        return simd_float3x3(
            simd_float3(800, 0, 320),    // fx, 0, cx
            simd_float3(0, 800, 240),    // 0, fy, cy
            simd_float3(0, 0, 1)         // 0, 0, 1
        )
    }
}

// MARK: - Test AR Frame Generator

class TestARFrameGenerator {
    
    func generateImageWithBall(
        ballPosition3D: simd_float3,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3
    ) -> TestImage {
        return generateImageWithMultipleBalls(
            ballPositions3D: [ballPosition3D],
            cameraTransform: cameraTransform,
            intrinsics: intrinsics
        )
    }
    
    func generateImageWithMultipleBalls(
        ballPositions3D: [simd_float3],
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3
    ) -> TestImage {
        
        let imageSize = CGSize(width: 640, height: 480)
        
        // Project 3D ball positions to 2D screen coordinates
        let coordinateTransform = ARCoordinateTransform()
        coordinateTransform.updateMatrices(
            cameraTransform: cameraTransform,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: imageSize,
            intrinsics: intrinsics
        )
        
        var ballConfigs: [BallConfig] = []
        
        for (index, ballPosition) in ballPositions3D.enumerated() {
            if let screenPoint = coordinateTransform.worldToScreen(ballPosition) {
                // Calculate ball size based on distance
                let distance = simd_length(ballPosition)
                let apparentSize = max(20, min(100, 1000 / distance)) // Size inversely proportional to distance
                
                let ballConfig = BallConfig(
                    color: getBallColorForIndex(index),
                    position: screenPoint,
                    size: CGSize(width: apparentSize, height: apparentSize)
                )
                ballConfigs.append(ballConfig)
            }
        }
        
        // Generate image using existing test image generator
        let imageGenerator = TestImageGenerator()
        return imageGenerator.generateMultipleBallsImage(
            ballConfigs: ballConfigs,
            imageSize: imageSize
        )
    }
    
    private func getBallColorForIndex(_ index: Int) -> TestBallColor {
        let colors: [TestBallColor] = [.red, .blue, .yellow, .green, .purple, .orange, .white, .black, .maroon]
        return colors[index % colors.count]
    }
}