import Foundation
import simd
import CoreGraphics

/// Protocol defining the interface for ball tracking systems
/// Implementations should handle trajectory prediction, occlusion handling, and multi-ball tracking
public protocol BallTrackingProtocol {
    
    // MARK: - Configuration
    
    /// Configuration settings for the tracking algorithm
    var configuration: BallTrackingConfiguration { get set }
    
    /// Whether the tracker is currently active
    var isActive: Bool { get }
    
    /// Number of balls currently being tracked
    var trackedBallCount: Int { get }
    
    // MARK: - Tracking Methods
    
    /// Update tracking with new detection results
    /// - Parameters:
    ///   - detections: New ball detections from detector
    ///   - timestamp: Frame timestamp for temporal consistency
    ///   - cameraTransform: Current camera transform for coordinate conversion
    /// - Returns: Array of tracked balls with predictions
    /// - Throws: BallTrackingError if tracking fails
    func updateTracking(with detections: [BallDetectionResult],
                       timestamp: TimeInterval,
                       cameraTransform: simd_float4x4) throws -> [TrackedBall]
    
    /// Predict ball positions at a future timestamp
    /// - Parameter futureTimestamp: Time to predict positions for
    /// - Returns: Array of predicted ball states
    /// - Throws: BallTrackingError if prediction fails
    func predictPositions(at futureTimestamp: TimeInterval) throws -> [BallPrediction]
    
    /// Get trajectory for a specific tracked ball
    /// - Parameters:
    ///   - ballId: Unique identifier of the tracked ball
    ///   - duration: How far into the future to predict (seconds)
    ///   - resolution: Number of points in trajectory (higher = smoother)
    /// - Returns: Array of predicted positions over time
    /// - Throws: BallTrackingError if ball not found or prediction fails
    func getTrajectory(for ballId: UUID, 
                      duration: TimeInterval,
                      resolution: Int) throws -> [TrajectoryPoint]
    
    // MARK: - Lifecycle Management
    
    /// Start the tracking system
    /// - Throws: BallTrackingError if initialization fails
    func startTracking() throws
    
    /// Stop tracking and cleanup resources
    func stopTracking()
    
    /// Reset all tracking state (lose all tracked balls)
    func reset()
    
    /// Remove a specific tracked ball
    /// - Parameter ballId: ID of ball to stop tracking
    func removeTrackedBall(_ ballId: UUID)
    
    // MARK: - State Query
    
    /// Get current state of all tracked balls
    /// - Returns: Dictionary mapping ball IDs to their current state
    func getCurrentState() -> [UUID: TrackedBall]
    
    /// Get tracking confidence for a specific ball
    /// - Parameter ballId: ID of the tracked ball
    /// - Returns: Confidence value (0.0 - 1.0), nil if ball not found
    func getTrackingConfidence(for ballId: UUID) -> Double?
    
    /// Check if a ball is currently being tracked
    /// - Parameter ballId: ID to check
    /// - Returns: True if ball is actively tracked
    func isTracking(ballId: UUID) -> Bool
    
    // MARK: - Performance Monitoring
    
    /// Get current tracking performance metrics
    /// - Returns: Dictionary containing performance data
    func getPerformanceMetrics() -> [String: Double]
    
    /// Validate tracking meets performance requirements
    /// - Parameter requirements: Performance thresholds to check
    /// - Returns: True if requirements are met
    func meetsPerformanceRequirements(_ requirements: TrackingPerformanceRequirements) -> Bool
}

// MARK: - Configuration Types

/// Configuration for ball tracking systems
public struct BallTrackingConfiguration {
    
    /// Maximum number of balls to track simultaneously
    public let maxTrackedBalls: Int
    
    /// Maximum time a ball can be undetected before losing track (seconds)
    public let maxLostTime: TimeInterval
    
    /// Minimum detections needed to establish a track
    public let minDetectionsForTrack: Int
    
    /// Kalman filter settings
    public let kalmanFilter: KalmanFilterSettings
    
    /// Association settings for matching detections to tracks
    public let association: AssociationSettings
    
    /// Occlusion handling settings
    public let occlusionHandling: OcclusionHandlingSettings
    
    /// Physics-based prediction settings
    public let physics: PhysicsSettings
    
    public init(maxTrackedBalls: Int = 16,
                maxLostTime: TimeInterval = 2.0,
                minDetectionsForTrack: Int = 3,
                kalmanFilter: KalmanFilterSettings = KalmanFilterSettings(),
                association: AssociationSettings = AssociationSettings(),
                occlusionHandling: OcclusionHandlingSettings = OcclusionHandlingSettings(),
                physics: PhysicsSettings = PhysicsSettings()) {
        self.maxTrackedBalls = maxTrackedBalls
        self.maxLostTime = maxLostTime
        self.minDetectionsForTrack = minDetectionsForTrack
        self.kalmanFilter = kalmanFilter
        self.association = association
        self.occlusionHandling = occlusionHandling
        self.physics = physics
    }
}

/// Kalman filter configuration for state estimation
public struct KalmanFilterSettings {
    /// Process noise covariance (higher = more responsive to changes)
    public let processNoiseCovariance: Double
    
    /// Measurement noise covariance (higher = trust measurements less)
    public let measurementNoiseCovariance: Double
    
    /// Initial state covariance
    public let initialStateCovariance: Double
    
    /// State transition model type
    public let stateModel: StateModel
    
    public init(processNoiseCovariance: Double = 0.1,
                measurementNoiseCovariance: Double = 0.5,
                initialStateCovariance: Double = 1.0,
                stateModel: StateModel = .constantVelocity) {
        self.processNoiseCovariance = processNoiseCovariance
        self.measurementNoiseCovariance = measurementNoiseCovariance
        self.initialStateCovariance = initialStateCovariance
        self.stateModel = stateModel
    }
}

/// State models for Kalman filtering
public enum StateModel: String, CaseIterable {
    case constantPosition = "constantPosition"     // Position only
    case constantVelocity = "constantVelocity"     // Position + velocity
    case constantAcceleration = "constantAcceleration" // Position + velocity + acceleration
}

/// Data association configuration for matching detections to tracks
public struct AssociationSettings {
    /// Maximum distance for associating detection with track (meters)
    public let maxAssociationDistance: Double
    
    /// Gate threshold for Mahalanobis distance
    public let gateThreshold: Double
    
    /// Association algorithm to use
    public let algorithm: AssociationAlgorithm
    
    /// Confidence threshold for accepting associations
    public let confidenceThreshold: Double
    
    public init(maxAssociationDistance: Double = 0.5,
                gateThreshold: Double = 9.21, // 99% confidence for 2D
                algorithm: AssociationAlgorithm = .hungarian,
                confidenceThreshold: Double = 0.5) {
        self.maxAssociationDistance = maxAssociationDistance
        self.gateThreshold = gateThreshold
        self.algorithm = algorithm
        self.confidenceThreshold = confidenceThreshold
    }
}

/// Data association algorithms
public enum AssociationAlgorithm: String, CaseIterable {
    case nearestNeighbor = "nearestNeighbor"     // Simple nearest neighbor
    case hungarian = "hungarian"                 // Hungarian algorithm (optimal)
    case globalNearest = "globalNearest"         // Global nearest neighbor
}

/// Occlusion handling configuration
public struct OcclusionHandlingSettings {
    /// Enable occlusion prediction and recovery
    public let enabled: Bool
    
    /// Maximum occlusion duration before losing track (seconds)
    public let maxOcclusionDuration: TimeInterval
    
    /// Confidence decay rate during occlusion (per second)
    public let confidenceDecayRate: Double
    
    /// Use physics-based prediction during occlusion
    public let usePhysicsPrediction: Bool
    
    /// Search region expansion factor during occlusion
    public let searchRegionExpansion: Double
    
    public init(enabled: Bool = true,
                maxOcclusionDuration: TimeInterval = 1.0,
                confidenceDecayRate: Double = 0.5,
                usePhysicsPrediction: Bool = true,
                searchRegionExpansion: Double = 1.5) {
        self.enabled = enabled
        self.maxOcclusionDuration = maxOcclusionDuration
        self.confidenceDecayRate = confidenceDecayRate
        self.usePhysicsPrediction = usePhysicsPrediction
        self.searchRegionExpansion = searchRegionExpansion
    }
}

/// Physics-based prediction settings
public struct PhysicsSettings {
    /// Enable physics-based trajectory prediction
    public let enabled: Bool
    
    /// Gravity acceleration (m/s²)
    public let gravity: Double
    
    /// Air resistance coefficient
    public let airResistance: Double
    
    /// Table friction coefficient
    public let tableFriction: Double
    
    /// Ball mass in kilograms
    public let ballMass: Double
    
    /// Ball radius in meters
    public let ballRadius: Double
    
    public init(enabled: Bool = true,
                gravity: Double = 9.81,
                airResistance: Double = 0.001,
                tableFriction: Double = 0.02,
                ballMass: Double = 0.165, // Standard pool ball
                ballRadius: Double = 0.02857) { // Standard pool ball
        self.enabled = enabled
        self.gravity = gravity
        self.airResistance = airResistance
        self.tableFriction = tableFriction
        self.ballMass = ballMass
        self.ballRadius = ballRadius
    }
}

// MARK: - Data Types

/// Represents a ball being tracked over time
public struct TrackedBall {
    /// Unique identifier for this tracked ball
    public let id: UUID
    
    /// Current 3D position in world coordinates
    public let position: simd_float3
    
    /// Current velocity vector (m/s)
    public let velocity: simd_float3
    
    /// Current acceleration vector (m/s²)
    public let acceleration: simd_float3
    
    /// Tracking confidence (0.0 - 1.0)
    public let confidence: Double
    
    /// Last detection timestamp
    public let lastDetectionTime: TimeInterval
    
    /// Time since ball was last detected
    public let timeSinceLastDetection: TimeInterval
    
    /// Tracking state
    public let state: TrackingState
    
    /// Predicted covariance matrix
    public let covariance: simd_float4x4
    
    /// Color information if available
    public let color: BallColor?
    
    /// Ball number if identified
    public let ballNumber: Int?
    
    public init(id: UUID = UUID(),
                position: simd_float3,
                velocity: simd_float3 = simd_float3(0, 0, 0),
                acceleration: simd_float3 = simd_float3(0, 0, 0),
                confidence: Double,
                lastDetectionTime: TimeInterval,
                timeSinceLastDetection: TimeInterval = 0.0,
                state: TrackingState = .normal,
                covariance: simd_float4x4 = matrix_identity_float4x4,
                color: BallColor? = nil,
                ballNumber: Int? = nil) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
        self.confidence = confidence
        self.lastDetectionTime = lastDetectionTime
        self.timeSinceLastDetection = timeSinceLastDetection
        self.state = state
        self.covariance = covariance
        self.color = color
        self.ballNumber = ballNumber
    }
}

/// Ball position prediction at a specific time
public struct BallPrediction {
    /// Ball identifier
    public let ballId: UUID
    
    /// Predicted position
    public let position: simd_float3
    
    /// Predicted velocity
    public let velocity: simd_float3
    
    /// Prediction confidence (0.0 - 1.0)
    public let confidence: Double
    
    /// Timestamp for this prediction
    public let timestamp: TimeInterval
    
    /// Uncertainty bounds (standard deviation)
    public let uncertainty: simd_float3
    
    public init(ballId: UUID,
                position: simd_float3,
                velocity: simd_float3,
                confidence: Double,
                timestamp: TimeInterval,
                uncertainty: simd_float3 = simd_float3(0.01, 0.01, 0.01)) {
        self.ballId = ballId
        self.position = position
        self.velocity = velocity
        self.confidence = confidence
        self.timestamp = timestamp
        self.uncertainty = uncertainty
    }
}

/// Point on a predicted trajectory
public struct TrajectoryPoint {
    /// Position at this point
    public let position: simd_float3
    
    /// Velocity at this point
    public let velocity: simd_float3
    
    /// Time offset from current time
    public let timeOffset: TimeInterval
    
    /// Confidence at this point
    public let confidence: Double
    
    public init(position: simd_float3,
                velocity: simd_float3,
                timeOffset: TimeInterval,
                confidence: Double) {
        self.position = position
        self.velocity = velocity
        self.timeOffset = timeOffset
        self.confidence = confidence
    }
}

/// Performance requirements for tracking validation
public struct TrackingPerformanceRequirements {
    /// Minimum tracking accuracy (percentage of successful tracks)
    public let minimumAccuracy: Double
    
    /// Maximum tracking latency in milliseconds
    public let maximumLatency: TimeInterval
    
    /// Maximum false positive rate
    public let maximumFalsePositiveRate: Double
    
    /// Maximum track loss rate (percentage of tracks lost per second)
    public let maximumTrackLossRate: Double
    
    /// Maximum memory usage in MB
    public let maximumMemoryUsage: Double
    
    public init(minimumAccuracy: Double = 0.95,
                maximumLatency: TimeInterval = 0.02,
                maximumFalsePositiveRate: Double = 0.05,
                maximumTrackLossRate: Double = 0.1,
                maximumMemoryUsage: Double = 50.0) {
        self.minimumAccuracy = minimumAccuracy
        self.maximumLatency = maximumLatency
        self.maximumFalsePositiveRate = maximumFalsePositiveRate
        self.maximumTrackLossRate = maximumTrackLossRate
        self.maximumMemoryUsage = maximumMemoryUsage
    }
}

// MARK: - Error Types

/// Errors that can occur during ball tracking
public enum BallTrackingError: Error, LocalizedError, Equatable {
    case initializationFailed(String)
    case trackingFailed(String)
    case predictionFailed(String)
    case ballNotFound(UUID)
    case configurationInvalid(String)
    case insufficientMemory
    case tooManyBalls(Int, maximum: Int)
    case kalmanFilterFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Tracking initialization failed: \(message)"
        case .trackingFailed(let message):
            return "Ball tracking failed: \(message)"
        case .predictionFailed(let message):
            return "Position prediction failed: \(message)"
        case .ballNotFound(let ballId):
            return "Ball with ID \(ballId) not found in tracking system"
        case .configurationInvalid(let message):
            return "Invalid tracking configuration: \(message)"
        case .insufficientMemory:
            return "Insufficient memory for tracking operations"
        case .tooManyBalls(let count, let maximum):
            return "Too many balls to track: \(count), maximum: \(maximum)"
        case .kalmanFilterFailed(let message):
            return "Kalman filter operation failed: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "Check device capabilities and tracking configuration"
        case .trackingFailed:
            return "Ensure consistent ball detections and proper lighting"
        case .predictionFailed:
            return "Check tracking state and reduce prediction duration"
        case .ballNotFound:
            return "Verify ball ID exists in current tracking session"
        case .configurationInvalid:
            return "Review and correct tracking configuration parameters"
        case .insufficientMemory:
            return "Reduce number of tracked balls or close other apps"
        case .tooManyBalls:
            return "Reduce maximum tracked balls in configuration"
        case .kalmanFilterFailed:
            return "Check filter parameters and tracking state consistency"
        }
    }
}