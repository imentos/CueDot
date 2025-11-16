import XCTest
import simd
@testable import CueDot

/// Comprehensive tests for BallDetectionResult model
/// Validates all properties, computed values, and edge cases
class BallDetectionResultTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testBasicInitialization() {
        // Given
        let position = SIMD3<Float>(1.0, 0.5, -2.0)
        let confidence: Float = 0.95
        let timestamp: TimeInterval = 12345.0
        
        // When
        let result = BallDetectionResult(
            ballCenter3D: position,
            confidence: confidence,
            timestamp: timestamp,
            isOccluded: false,
            hasMultipleBalls: false
        )
        
        // Then
        XCTAssertEqual(result.ballCenter3D, position)
        XCTAssertEqual(result.confidence, confidence)
        XCTAssertEqual(result.timestamp, timestamp)
        XCTAssertFalse(result.isOccluded)
        XCTAssertFalse(result.hasMultipleBalls)
    }
    
    func testDefaultTimestamp() {
        // Given
        let beforeTime = ProcessInfo.processInfo.systemUptime
        
        // When
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.9
        )
        
        let afterTime = ProcessInfo.processInfo.systemUptime
        
        // Then
        XCTAssertGreaterThanOrEqual(result.timestamp, beforeTime)
        XCTAssertLessThanOrEqual(result.timestamp, afterTime)
    }
    
    func testConfidenceClampingUpperBound() {
        // Given
        let overConfidence: Float = 1.5
        
        // When
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: overConfidence
        )
        
        // Then
        XCTAssertEqual(result.confidence, 1.0, "Confidence should be clamped to 1.0")
    }
    
    func testConfidenceClampingLowerBound() {
        // Given
        let negativeConfidence: Float = -0.5
        
        // When
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: negativeConfidence
        )
        
        // Then
        XCTAssertEqual(result.confidence, 0.0, "Confidence should be clamped to 0.0")
    }
    
    // MARK: - Computed Properties Tests
    
    func testIsReliableForTracking_ReliableCase() {
        // Given
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.90,
            isOccluded: false,
            hasMultipleBalls: false
        )
        
        // When & Then
        XCTAssertTrue(result.isReliableForTracking)
    }
    
    func testIsReliableForTracking_LowConfidence() {
        // Given
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.80, // Below threshold
            isOccluded: false,
            hasMultipleBalls: false
        )
        
        // When & Then
        XCTAssertFalse(result.isReliableForTracking)
    }
    
    func testIsReliableForTracking_MultipleBalls() {
        // Given
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.95,
            isOccluded: false,
            hasMultipleBalls: true // Should make it unreliable
        )
        
        // When & Then
        XCTAssertFalse(result.isReliableForTracking)
    }
    
    func testIsReliableForTracking_OccludedButHighConfidence() {
        // Given - occlusion alone doesn't affect reliability
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.95,
            isOccluded: true,
            hasMultipleBalls: false
        )
        
        // When & Then
        XCTAssertTrue(result.isReliableForTracking, "Occlusion alone should not affect reliability")
    }
    
    func testDistanceFromOrigin() {
        // Given
        let position = SIMD3<Float>(3.0, 4.0, 0.0) // 3-4-5 triangle
        let result = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.9
        )
        
        // When & Then
        XCTAssertEqual(result.distanceFromOrigin, 5.0, accuracy: 0.001)
    }
    
    func testDistanceFromOrigin_AtOrigin() {
        // Given
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, 0),
            confidence: 0.9
        )
        
        // When & Then
        XCTAssertEqual(result.distanceFromOrigin, 0.0)
    }
    
    // MARK: - Equatable Tests
    
    func testEquality_IdenticalResults() {
        // Given
        let position = SIMD3<Float>(1.0, 2.0, 3.0)
        let timestamp: TimeInterval = 12345.0
        
        let result1 = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.95,
            timestamp: timestamp,
            isOccluded: true,
            hasMultipleBalls: false
        )
        
        let result2 = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.95,
            timestamp: timestamp,
            isOccluded: true,
            hasMultipleBalls: false
        )
        
        // When & Then
        XCTAssertEqual(result1, result2)
    }
    
    func testInequality_DifferentPositions() {
        // Given
        let result1 = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(1.0, 0.0, 0.0),
            confidence: 0.95
        )
        
        let result2 = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(2.0, 0.0, 0.0),
            confidence: 0.95
        )
        
        // When & Then
        XCTAssertNotEqual(result1, result2)
    }
    
    func testInequality_DifferentConfidence() {
        // Given
        let position = SIMD3<Float>(1.0, 0.0, 0.0)
        
        let result1 = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.95
        )
        
        let result2 = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.85
        )
        
        // When & Then
        XCTAssertNotEqual(result1, result2)
    }
    
    func testInequality_DifferentFlags() {
        // Given
        let position = SIMD3<Float>(1.0, 0.0, 0.0)
        
        let result1 = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.95,
            isOccluded: false,
            hasMultipleBalls: false
        )
        
        let result2 = BallDetectionResult(
            ballCenter3D: position,
            confidence: 0.95,
            isOccluded: true,
            hasMultipleBalls: false
        )
        
        // When & Then
        XCTAssertNotEqual(result1, result2)
    }
    
    // MARK: - Description Tests
    
    func testDescription() {
        // Given
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(1.0, 2.0, 3.0),
            confidence: 0.95,
            timestamp: 12345.0,
            isOccluded: true,
            hasMultipleBalls: false
        )
        
        // When
        let description = result.description
        
        // Then
        XCTAssertTrue(description.contains("BallDetectionResult"))
        XCTAssertTrue(description.contains("1.0"))
        XCTAssertTrue(description.contains("2.0"))
        XCTAssertTrue(description.contains("3.0"))
        XCTAssertTrue(description.contains("0.95"))
        XCTAssertTrue(description.contains("12345.0"))
        XCTAssertTrue(description.contains("true"))
        XCTAssertTrue(description.contains("false"))
    }
    
    // MARK: - Test Helper Tests (Debug Only)
    
    func testTestDefault() {
        // When
        let result = BallDetectionResult.testDefault()
        
        // Then
        XCTAssertEqual(result.ballCenter3D, SIMD3<Float>(0, 0, -1))
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertFalse(result.isOccluded)
        XCTAssertFalse(result.hasMultipleBalls)
        XCTAssertTrue(result.isReliableForTracking)
    }
    
    func testTestDefaultWithCustomPosition() {
        // Given
        let customPosition = SIMD3<Float>(5.0, 10.0, -15.0)
        
        // When
        let result = BallDetectionResult.testDefault(ballCenter3D: customPosition)
        
        // Then
        XCTAssertEqual(result.ballCenter3D, customPosition)
        XCTAssertTrue(result.isReliableForTracking)
    }
    
    func testTestUnreliable() {
        // When
        let result = BallDetectionResult.testUnreliable()
        
        // Then
        XCTAssertEqual(result.confidence, 0.3)
        XCTAssertTrue(result.isOccluded)
        XCTAssertTrue(result.hasMultipleBalls)
        XCTAssertFalse(result.isReliableForTracking)
    }
    
    // MARK: - Edge Cases
    
    func testExtremePositions() {
        // Test very large distances
        let extremePosition = SIMD3<Float>(1000.0, -1000.0, 1000.0)
        let result = BallDetectionResult(
            ballCenter3D: extremePosition,
            confidence: 0.9
        )
        
        XCTAssertEqual(result.ballCenter3D, extremePosition)
        XCTAssertGreaterThan(result.distanceFromOrigin, 1500.0)
    }
    
    func testNearZeroConfidence() {
        // Test very small but positive confidence
        let result = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.001
        )
        
        XCTAssertEqual(result.confidence, 0.001)
        XCTAssertFalse(result.isReliableForTracking)
    }
}