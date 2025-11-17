import Foundation
import simd

/// Result of ball tracking operation, containing ball position, velocity and metadata
public struct TrackingResult {
    /// Unique identifier for this tracked ball
    public let trackID: Int
    
    /// 3D position of the ball in world coordinates
    public let position: simd_float3
    
    /// 3D velocity vector of the ball
    public let velocity: simd_float3
    
    /// Confidence level of the tracking [0.0, 1.0]
    public let confidence: Float
    
    /// Whether this track is currently being detected vs predicted
    public let isDetected: Bool
    
    /// Timestamp of the last update
    public let timestamp: TimeInterval
    
    /// Position uncertainty (standard deviation in each axis)
    public let uncertainty: simd_float3
    
    /// Current state of this ball track
    public let state: BallTrackState
    
    /// Additional metadata about the tracking
    public let metadata: TrackingMetadata?
    
    public init(trackID: Int,
               position: simd_float3,
               velocity: simd_float3,
               confidence: Float,
               isDetected: Bool,
               timestamp: TimeInterval,
               uncertainty: simd_float3 = simd_float3(0, 0, 0),
               state: BallTrackState = .active,
               metadata: TrackingMetadata? = nil) {
        self.trackID = trackID
        self.position = position
        self.velocity = velocity
        self.confidence = confidence
        self.isDetected = isDetected
        self.timestamp = timestamp
        self.uncertainty = uncertainty
        self.state = state
        self.metadata = metadata
    }
}

/// State of individual ball tracking
public enum BallTrackState {
    /// Track is actively being updated with detections
    case active
    
    /// Track is being predicted but not detected
    case predicted
    
    /// Track is experiencing jitter or uncertainty
    case jittering(severity: Float)
    
    /// Track has been lost and may be removed soon
    case lost(reason: String)
    
    /// Track is temporarily occluded but expected to return
    case occluded
}

/// Additional metadata about tracking performance and characteristics
public struct TrackingMetadata {
    /// How long this track has existed (in seconds)
    public let trackAge: TimeInterval
    
    /// Number of consecutive frames without detection
    public let consecutiveMisses: Int
    
    /// Total number of detections for this track
    public let totalDetections: Int
    
    /// Average confidence over the track lifetime
    public let averageConfidence: Float
    
    /// Whether this track is stable (low jitter, consistent detections)
    public let isStable: Bool
    
    /// Estimated ball type or characteristics if known
    public let ballType: BallType?
    
    public init(trackAge: TimeInterval,
               consecutiveMisses: Int,
               totalDetections: Int,
               averageConfidence: Float,
               isStable: Bool,
               ballType: BallType? = nil) {
        self.trackAge = trackAge
        self.consecutiveMisses = consecutiveMisses
        self.totalDetections = totalDetections
        self.averageConfidence = averageConfidence
        self.isStable = isStable
        self.ballType = ballType
    }
}

/// Ball type classification for different pool balls
public enum BallType {
    case cueBall
    case solid(number: Int)
    case stripe(number: Int)
    case eightBall
    case unknown
    
    public var displayName: String {
        switch self {
        case .cueBall:
            return "Cue Ball"
        case .solid(let number):
            return "Solid \(number)"
        case .stripe(let number):
            return "Stripe \(number)"
        case .eightBall:
            return "8-Ball"
        case .unknown:
            return "Unknown Ball"
        }
    }
    
    public var ballNumber: Int? {
        switch self {
        case .solid(let number), .stripe(let number):
            return number
        case .eightBall:
            return 8
        case .cueBall, .unknown:
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension TrackingResult {
    /// Check if this track needs attention (low confidence, lost, etc.)
    public var needsAttention: Bool {
        switch state {
        case .lost, .jittering:
            return true
        case .predicted:
            return confidence < 0.3
        case .active, .occluded:
            return confidence < 0.1
        }
    }
    
    /// Get a human-readable description of the track state
    public var stateDescription: String {
        switch state {
        case .active:
            return "Active"
        case .predicted:
            return "Predicted"
        case .jittering(let severity):
            return String(format: "Jittering (%.1f%%)", severity * 100)
        case .lost(let reason):
            return "Lost: \(reason)"
        case .occluded:
            return "Occluded"
        }
    }
    
    /// Calculate the speed of the ball
    public var speed: Float {
        return length(velocity)
    }
    
    /// Predict position at a future time
    public func predictPosition(at futureTime: TimeInterval) -> simd_float3 {
        let deltaTime = Float(futureTime - timestamp)
        return position + velocity * deltaTime
    }
}

extension BallTrackState {
    /// Whether this state indicates the track is reliable
    public var isReliable: Bool {
        switch self {
        case .active, .predicted, .occluded:
            return true
        case .jittering(let severity):
            return severity < 0.5
        case .lost:
            return false
        }
    }
    
    /// Whether this state indicates the ball is currently visible
    public var isVisible: Bool {
        switch self {
        case .active:
            return true
        case .predicted, .jittering, .lost, .occluded:
            return false
        }
    }
}