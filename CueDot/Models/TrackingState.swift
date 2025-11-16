import Foundation

/// Represents the current state of AR tracking quality for the session
/// Maps directly to ARKit's tracking states with additional context for our use case
public enum TrackingState {
    
    /// Normal tracking with high confidence
    /// - Position data is reliable and suitable for overlay rendering
    /// - All sensors functioning optimally
    case normal
    
    /// Limited tracking with reduced confidence
    /// - Position data may be less accurate
    /// - Could be due to insufficient features, excessive motion, or poor lighting
    /// - Application should continue operation but may show warnings
    case limited(reason: LimitedTrackingReason)
    
    /// Tracking is not available
    /// - Position data is unreliable or unavailable
    /// - AR overlays should be hidden
    /// - User should be prompted to improve conditions
    case notAvailable(reason: UnavailableReason)
}

// MARK: - Tracking Limitation Reasons

/// Specific reasons why tracking might be limited
public enum LimitedTrackingReason {
    /// Insufficient visual features in the environment
    case insufficientFeatures
    
    /// Device is moving too rapidly for accurate tracking
    case excessiveMotion
    
    /// Lighting conditions are poor (too dark, too bright, or changing rapidly)
    case poorLighting
    
    /// AR session is still initializing
    case initializing
    
    /// Temporary sensor issues or calibration problems
    case sensorIssues
}

/// Specific reasons why tracking is completely unavailable
public enum UnavailableReason {
    /// Camera access is denied or camera is not available
    case cameraUnavailable
    
    /// Device does not support required AR features
    case unsupportedConfiguration
    
    /// AR session has encountered a critical error
    case sessionInterrupted
    
    /// Device sensors are not functioning
    case sensorFailure
}

// MARK: - TrackingState Extensions

extension TrackingState {
    
    /// Returns true if tracking quality is sufficient for reliable overlay positioning
    public var isReliableForOverlay: Bool {
        switch self {
        case .normal:
            return true
        case .limited(let reason):
            // Even with limited tracking, we can still show overlays for some cases
            switch reason {
            case .insufficientFeatures, .poorLighting:
                return true // Position may still be usable
            case .excessiveMotion, .initializing, .sensorIssues:
                return false // Position likely unreliable
            }
        case .notAvailable:
            return false
        }
    }
    
    /// Returns a user-friendly description of the current tracking state
    public var userDescription: String {
        switch self {
        case .normal:
            return "Tracking normally"
            
        case .limited(let reason):
            switch reason {
            case .insufficientFeatures:
                return "Limited tracking: Try pointing at textured surfaces"
            case .excessiveMotion:
                return "Limited tracking: Move device more slowly"
            case .poorLighting:
                return "Limited tracking: Improve lighting conditions"
            case .initializing:
                return "Initializing AR tracking..."
            case .sensorIssues:
                return "Limited tracking: Sensor calibration in progress"
            }
            
        case .notAvailable(let reason):
            switch reason {
            case .cameraUnavailable:
                return "Camera unavailable: Check permissions"
            case .unsupportedConfiguration:
                return "AR not supported on this device"
            case .sessionInterrupted:
                return "AR session interrupted"
            case .sensorFailure:
                return "Device sensor error"
            }
        }
    }
    
    /// Returns the severity level for UI presentation
    public var severity: TrackingSeverity {
        switch self {
        case .normal:
            return .none
        case .limited(let reason):
            switch reason {
            case .insufficientFeatures, .poorLighting:
                return .warning
            case .excessiveMotion, .initializing, .sensorIssues:
                return .caution
            }
        case .notAvailable:
            return .critical
        }
    }
}

/// Severity levels for tracking state presentation
public enum TrackingSeverity {
    case none       // Green - all good
    case warning    // Yellow - some issues but functional
    case caution    // Orange - significant issues
    case critical   // Red - major problems
}

// MARK: - Equatable Conformance

extension TrackingState: Equatable {
    public static func == (lhs: TrackingState, rhs: TrackingState) -> Bool {
        switch (lhs, rhs) {
        case (.normal, .normal):
            return true
        case (.limited(let lhsReason), .limited(let rhsReason)):
            return lhsReason == rhsReason
        case (.notAvailable(let lhsReason), .notAvailable(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}

extension LimitedTrackingReason: Equatable {}
extension UnavailableReason: Equatable {}
extension TrackingSeverity: Equatable {}

// MARK: - CustomStringConvertible Conformance

extension TrackingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .normal:
            return "TrackingState.normal"
        case .limited(let reason):
            return "TrackingState.limited(\(reason))"
        case .notAvailable(let reason):
            return "TrackingState.notAvailable(\(reason))"
        }
    }
}

extension LimitedTrackingReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .insufficientFeatures: return "insufficientFeatures"
        case .excessiveMotion: return "excessiveMotion"
        case .poorLighting: return "poorLighting"
        case .initializing: return "initializing"
        case .sensorIssues: return "sensorIssues"
        }
    }
}

extension UnavailableReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cameraUnavailable: return "cameraUnavailable"
        case .unsupportedConfiguration: return "unsupportedConfiguration"
        case .sessionInterrupted: return "sessionInterrupted"
        case .sensorFailure: return "sensorFailure"
        }
    }
}

// MARK: - Test Helpers

#if DEBUG
extension TrackingState {
    /// Creates a normal tracking state for testing
    public static var testNormal: TrackingState {
        return .normal
    }
    
    /// Creates a limited tracking state with insufficient features for testing
    public static var testLimitedFeatures: TrackingState {
        return .limited(reason: .insufficientFeatures)
    }
    
    /// Creates an unavailable state with camera issues for testing
    public static var testUnavailableCamera: TrackingState {
        return .notAvailable(reason: .cameraUnavailable)
    }
}
#endif