import Foundation
import simd

/// Enhanced ball detection result with unique ID and additional metadata for multi-ball scenarios
public struct EnhancedBallDetectionResult {
    
    // MARK: - Core Properties (from original BallDetectionResult)
    
    /// Unique identifier for this specific detection
    public let id: UUID
    
    /// The 3D world coordinates of the detected ball center in meters
    public let ballCenter3D: SIMD3<Float>
    
    /// Detection confidence score from 0.0 to 1.0
    public let confidence: Float
    
    /// Timestamp when this detection was captured
    public let timestamp: TimeInterval
    
    /// Indicates if the detected ball is partially occluded
    public let isOccluded: Bool
    
    /// Indicates if multiple potential balls were detected in the same frame
    public let hasMultipleBalls: Bool
    
    // MARK: - Enhanced Properties for Multi-ball Detection
    
    /// Type/category of the detected ball (e.g., cue ball, numbered ball, etc.)
    public let ballType: BallType
    
    /// Enhanced metadata for clustering and tracking
    public let metadata: BallDetectionMetadata?
    
    // MARK: - Ball Type Definition
    
    public enum BallType: Equatable {
        case cueBall        // White cue ball
        case solid(Int)     // Solid numbered balls (1-7)
        case stripe(Int)    // Striped numbered balls (9-15)
        case eightBall      // Black 8-ball
        case unknown        // Unidentified ball
        
        public var displayName: String {
            switch self {
            case .cueBall:
                return "Cue Ball"
            case .solid(let number):
                return "Ball \(number)"
            case .stripe(let number):
                return "Ball \(number)"
            case .eightBall:
                return "8-Ball"
            case .unknown:
                return "Unknown Ball"
            }
        }
        
        public var isNumbered: Bool {
            switch self {
            case .solid(_), .stripe(_), .eightBall:
                return true
            case .cueBall, .unknown:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        ballCenter3D: SIMD3<Float>,
        confidence: Float,
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime,
        isOccluded: Bool = false,
        hasMultipleBalls: Bool = false,
        ballType: BallType = .unknown,
        metadata: BallDetectionMetadata? = nil
    ) {
        self.id = id
        self.ballCenter3D = ballCenter3D
        self.confidence = max(0.0, min(1.0, confidence))
        self.timestamp = timestamp
        self.isOccluded = isOccluded
        self.hasMultipleBalls = hasMultipleBalls
        self.ballType = ballType
        self.metadata = metadata
    }
    
    /// Initialize from original BallDetectionResult
    public init(from original: BallDetectionResult, 
                id: UUID = UUID(),
                ballType: BallType = .unknown,
                metadata: BallDetectionMetadata? = nil) {
        self.id = id
        self.ballCenter3D = original.ballCenter3D
        self.confidence = original.confidence
        self.timestamp = original.timestamp
        self.isOccluded = original.isOccluded
        self.hasMultipleBalls = original.hasMultipleBalls
        self.ballType = ballType
        self.metadata = metadata
    }
    
    // MARK: - Computed Properties
    
    /// Convenience accessor for 3D center (matches MultiBall engine interface)
    public var center3D: SIMD3<Float> {
        return ballCenter3D
    }
    
    /// Returns true if this detection should be considered reliable for tracking
    public var isReliableForTracking: Bool {
        return confidence >= 0.85 && !hasMultipleBalls
    }
    
    /// Distance from origin in meters
    public var distanceFromOrigin: Float {
        return length(ballCenter3D)
    }
    
    /// Convert back to original BallDetectionResult format
    public var asBallDetectionResult: BallDetectionResult {
        return BallDetectionResult(
            ballCenter3D: ballCenter3D,
            confidence: confidence,
            timestamp: timestamp,
            isOccluded: isOccluded,
            hasMultipleBalls: hasMultipleBalls
        )
    }
    
    // MARK: - Bounding Box (estimated for clustering)
    
    /// Approximate 2D bounding box for clustering algorithms
    /// This is a simplified implementation - in practice, you'd project 3D to screen space
    public var boundingBox: CGRect {
        let screenX = ballCenter3D.x * 100 + 250  // Simple projection
        let screenY = -ballCenter3D.z * 100 + 250
        let size: CGFloat = max(20, 50 / CGFloat(distanceFromOrigin))  // Size based on distance
        
        return CGRect(
            x: CGFloat(screenX) - size/2,
            y: CGFloat(screenY) - size/2,
            width: size,
            height: size
        )
    }
}

// MARK: - Metadata Structure

public struct BallDetectionMetadata {
    public let trackingId: String?
    public let clusterInfo: ClusterInfo?
    public let associationType: String?
    public let sceneComplexity: String?
    
    public init(
        trackingId: String? = nil,
        clusterInfo: ClusterInfo? = nil,
        associationType: String? = nil,
        sceneComplexity: String? = nil
    ) {
        self.trackingId = trackingId
        self.clusterInfo = clusterInfo
        self.associationType = associationType
        self.sceneComplexity = sceneComplexity
    }
}

public struct ClusterInfo {
    public let clusterId: String
    public let clusterType: String
    public let ballCount: Int
    public let clusterConfidence: Float
    
    public init(
        clusterId: String,
        clusterType: String,
        ballCount: Int,
        clusterConfidence: Float
    ) {
        self.clusterId = clusterId
        self.clusterType = clusterType
        self.ballCount = ballCount
        self.clusterConfidence = clusterConfidence
    }
}

// MARK: - Conformances

extension EnhancedBallDetectionResult: Equatable {
    public static func == (lhs: EnhancedBallDetectionResult, rhs: EnhancedBallDetectionResult) -> Bool {
        return lhs.id == rhs.id &&
               lhs.ballCenter3D == rhs.ballCenter3D &&
               lhs.confidence == rhs.confidence &&
               lhs.timestamp == rhs.timestamp &&
               lhs.ballType == rhs.ballType
    }
}

extension EnhancedBallDetectionResult: Identifiable {
    // UUID id is already defined as a property
}

extension EnhancedBallDetectionResult: CustomStringConvertible {
    public var description: String {
        let metadataDesc = metadata != nil ? ", metadata: \(metadata!)" : ""
        return """
        EnhancedBallDetectionResult(
            id: \(id),
            center: (\(ballCenter3D.x), \(ballCenter3D.y), \(ballCenter3D.z)),
            confidence: \(confidence),
            ballType: \(ballType.displayName),
            timestamp: \(timestamp)\(metadataDesc)
        )
        """
    }
}

// MARK: - Conversion Extensions

extension Array where Element == BallDetectionResult {
    /// Convert array of original BallDetectionResult to EnhancedBallDetectionResult
    public func toEnhanced() -> [EnhancedBallDetectionResult] {
        return self.map { EnhancedBallDetectionResult(from: $0) }
    }
}

extension Array where Element == EnhancedBallDetectionResult {
    /// Convert array of enhanced results back to original format
    public func toOriginal() -> [BallDetectionResult] {
        return self.map { $0.asBallDetectionResult }
    }
}

// MARK: - Test Helpers

#if DEBUG
extension EnhancedBallDetectionResult {
    public static func testDefault(
        ballCenter3D: SIMD3<Float> = SIMD3<Float>(0, 0, -1),
        ballType: BallType = .cueBall
    ) -> EnhancedBallDetectionResult {
        return EnhancedBallDetectionResult(
            ballCenter3D: ballCenter3D,
            confidence: 0.95,
            ballType: ballType
        )
    }
    
    public static func testCluster() -> [EnhancedBallDetectionResult] {
        return [
            testDefault(ballCenter3D: SIMD3<Float>(0, 0, -1), ballType: .cueBall),
            testDefault(ballCenter3D: SIMD3<Float>(0.1, 0, -1), ballType: .solid(1)),
            testDefault(ballCenter3D: SIMD3<Float>(-0.1, 0, -1), ballType: .solid(2)),
        ]
    }
}
#endif