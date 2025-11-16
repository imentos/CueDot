import Foundation
import simd

/// Represents the result of a ball detection operation with comprehensive metadata
/// for tracking and confidence assessment.
public struct BallDetectionResult {
    
    // MARK: - Properties
    
    /// The 3D world coordinates of the detected ball center in meters
    /// Uses ARKit's coordinate system where Y is up, X is right, Z is toward the user
    public let ballCenter3D: SIMD3<Float>
    
    /// Detection confidence score from 0.0 (no confidence) to 1.0 (maximum confidence)
    /// Combines Vision framework confidence, color matching, and geometric validation
    public let confidence: Float
    
    /// Timestamp when this detection was captured, in seconds since system boot
    /// Used for temporal tracking and latency calculations
    public let timestamp: TimeInterval
    
    /// Indicates if the detected ball is partially occluded by other objects
    /// When true, position may be less reliable and overlay should handle gracefully
    public let isOccluded: Bool
    
    /// Indicates if multiple potential balls were detected in the same frame
    /// When true, confidence should be treated as unreliable for tracking
    public let hasMultipleBalls: Bool
    
    // MARK: - Initialization
    
    /// Creates a new ball detection result with validation
    /// - Parameters:
    ///   - ballCenter3D: 3D world coordinates in meters
    ///   - confidence: Confidence score, automatically clamped to [0.0, 1.0]
    ///   - timestamp: Detection timestamp, defaults to current time
    ///   - isOccluded: Whether the ball is partially hidden
    ///   - hasMultipleBalls: Whether multiple balls were detected
    public init(
        ballCenter3D: SIMD3<Float>,
        confidence: Float,
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime,
        isOccluded: Bool = false,
        hasMultipleBalls: Bool = false
    ) {
        self.ballCenter3D = ballCenter3D
        self.confidence = max(0.0, min(1.0, confidence)) // Clamp to valid range
        self.timestamp = timestamp
        self.isOccluded = isOccluded
        self.hasMultipleBalls = hasMultipleBalls
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if this detection should be considered reliable for tracking
    /// Combines confidence threshold with occlusion and multi-ball states
    public var isReliableForTracking: Bool {
        return confidence >= 0.85 && !hasMultipleBalls
    }
    
    /// Distance from origin in meters - useful for size scaling calculations
    public var distanceFromOrigin: Float {
        return length(ballCenter3D)
    }
}

// MARK: - Equatable Conformance

extension BallDetectionResult: Equatable {
    /// Two detection results are equal if all their properties match exactly
    /// Note: Floating point comparison uses exact equality - consider using
    /// approximate equality in tests with epsilon tolerance
    public static func == (lhs: BallDetectionResult, rhs: BallDetectionResult) -> Bool {
        return lhs.ballCenter3D == rhs.ballCenter3D &&
               lhs.confidence == rhs.confidence &&
               lhs.timestamp == rhs.timestamp &&
               lhs.isOccluded == rhs.isOccluded &&
               lhs.hasMultipleBalls == rhs.hasMultipleBalls
    }
}

// MARK: - CustomStringConvertible Conformance

extension BallDetectionResult: CustomStringConvertible {
    /// Human-readable description for debugging and logging
    public var description: String {
        return """
        BallDetectionResult(
            center: (\(ballCenter3D.x), \(ballCenter3D.y), \(ballCenter3D.z)),
            confidence: \(confidence),
            timestamp: \(timestamp),
            occluded: \(isOccluded),
            multipleBalls: \(hasMultipleBalls)
        )
        """
    }
}

// MARK: - Test Helpers

#if DEBUG
extension BallDetectionResult {
    /// Creates a detection result with default values for testing
    /// - Parameter ballCenter3D: The 3D position, defaults to origin
    /// - Returns: A reliable detection result suitable for testing
    public static func testDefault(
        ballCenter3D: SIMD3<Float> = SIMD3<Float>(0, 0, -1)
    ) -> BallDetectionResult {
        return BallDetectionResult(
            ballCenter3D: ballCenter3D,
            confidence: 0.95,
            timestamp: ProcessInfo.processInfo.systemUptime,
            isOccluded: false,
            hasMultipleBalls: false
        )
    }
    
    /// Creates an unreliable detection result for testing edge cases
    /// - Returns: A detection result with low confidence and multiple issues
    public static func testUnreliable() -> BallDetectionResult {
        return BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 0, -1),
            confidence: 0.3,
            timestamp: ProcessInfo.processInfo.systemUptime,
            isOccluded: true,
            hasMultipleBalls: true
        )
    }
}
#endif