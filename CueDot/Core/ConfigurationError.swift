import Foundation

/// Represents errors that can occur during configuration validation and setup
public enum ConfigurationError: Error {
    
    // MARK: - Validation Errors
    
    /// Confidence value is outside valid range (0.0-1.0)
    case invalidConfidence(Float)
    
    /// Distance value is outside reasonable range (0.1m-10m)
    case invalidDistance(Float)
    
    /// Ball diameter is outside acceptable range (40mm-80mm)
    case invalidBallDiameter(Float)
    
    /// Frame rate is outside acceptable range (15-120 fps)
    case invalidFrameRate(Int)
    
    /// Latency exceeds acceptable bounds (>100ms)
    case invalidLatency(Int)
    
    /// GPU usage exceeds reasonable limits (>50%)
    case invalidGPUUsage(Float)
    
    // MARK: - Hardware Errors
    
    /// Device does not support required AR features
    case unsupportedHardware
    
    /// Camera permissions not granted
    case cameraPermissionDenied
    
    /// Device sensors are not functioning properly
    case sensorUnavailable
    
    // MARK: - Configuration Errors
    
    /// Invalid configuration parameter combination
    case invalidParameterCombination(String)
    
    /// Required configuration value is missing
    case missingRequiredParameter(String)
    
    /// Configuration value exceeds platform limits
    case exceedsPlatformLimits(String)
}

// MARK: - LocalizedError Conformance

extension ConfigurationError: LocalizedError {
    
    /// User-friendly error description for display in UI
    public var errorDescription: String? {
        switch self {
        case .invalidConfidence(let value):
            return "Invalid confidence value: \(value). Must be between 0.0 and 1.0."
            
        case .invalidDistance(let value):
            return "Invalid distance: \(value)m. Must be between 0.1m and 10m."
            
        case .invalidBallDiameter(let value):
            return "Invalid ball diameter: \(value * 1000)mm. Must be between 40mm and 80mm."
            
        case .invalidFrameRate(let value):
            return "Invalid frame rate: \(value) fps. Must be between 15 and 120 fps."
            
        case .invalidLatency(let value):
            return "Invalid latency: \(value)ms. Must be less than 100ms."
            
        case .invalidGPUUsage(let value):
            return "Invalid GPU usage: \(value)%. Must be less than 50%."
            
        case .unsupportedHardware:
            return "This device does not support the required AR features."
            
        case .cameraPermissionDenied:
            return "Camera permission is required for AR functionality."
            
        case .sensorUnavailable:
            return "Required device sensors are not available or functioning."
            
        case .invalidParameterCombination(let description):
            return "Invalid parameter combination: \(description)"
            
        case .missingRequiredParameter(let parameter):
            return "Missing required configuration parameter: \(parameter)"
            
        case .exceedsPlatformLimits(let description):
            return "Configuration exceeds platform limits: \(description)"
        }
    }
    
    /// Detailed error description for logging and debugging
    public var failureReason: String? {
        switch self {
        case .invalidConfidence(let value):
            return "Confidence value \(value) is outside the valid range. Confidence must be normalized between 0.0 (no confidence) and 1.0 (maximum confidence)."
            
        case .invalidDistance(let value):
            return "Distance value \(value)m is outside reasonable range for pool table context. Expected range is 0.1m to 10m."
            
        case .invalidBallDiameter(let value):
            return "Ball diameter \(value * 1000)mm is outside acceptable range. Pool balls typically range from 40mm to 80mm."
            
        case .invalidFrameRate(let value):
            return "Frame rate \(value) fps is outside acceptable range. AR applications require 15-120 fps for proper functionality."
            
        case .invalidLatency(let value):
            return "Latency \(value)ms exceeds acceptable bounds. Real-time AR requires latency under 100ms for good user experience."
            
        case .invalidGPUUsage(let value):
            return "GPU usage \(value)% exceeds reasonable limits. High GPU usage can cause overheating and battery drain."
            
        case .unsupportedHardware:
            return "Device lacks required hardware capabilities such as ARKit support, adequate processing power, or necessary sensors."
            
        case .cameraPermissionDenied:
            return "Camera access is required for AR ball detection. Grant camera permissions in Settings."
            
        case .sensorUnavailable:
            return "Motion sensors, gyroscope, or other required hardware components are not functioning properly."
            
        case .invalidParameterCombination(let description):
            return "Configuration parameters conflict with each other: \(description)"
            
        case .missingRequiredParameter(let parameter):
            return "Required configuration parameter '\(parameter)' is not set or is nil."
            
        case .exceedsPlatformLimits(let description):
            return "Configuration value exceeds what the current platform can support: \(description)"
        }
    }
    
    /// Recovery suggestions for the user
    public var recoverySuggestion: String? {
        switch self {
        case .invalidConfidence, .invalidDistance, .invalidBallDiameter, .invalidFrameRate, .invalidLatency, .invalidGPUUsage:
            return "Check the input values and ensure they fall within the specified ranges."
            
        case .unsupportedHardware:
            return "Use a device with ARKit support and adequate processing power."
            
        case .cameraPermissionDenied:
            return "Grant camera permissions in Settings > Privacy & Security > Camera."
            
        case .sensorUnavailable:
            return "Restart the device or contact support if sensors continue to malfunction."
            
        case .invalidParameterCombination:
            return "Review configuration parameters and ensure they are compatible with each other."
            
        case .missingRequiredParameter:
            return "Provide the missing configuration parameter with a valid value."
            
        case .exceedsPlatformLimits:
            return "Reduce the configuration values to stay within platform capabilities."
        }
    }
}

// MARK: - Error Categories

extension ConfigurationError {
    
    /// Determines if this error is recoverable through user action
    public var isRecoverable: Bool {
        switch self {
        case .cameraPermissionDenied:
            return true
        case .invalidConfidence, .invalidDistance, .invalidBallDiameter, .invalidFrameRate, .invalidLatency, .invalidGPUUsage:
            return true
        case .invalidParameterCombination, .missingRequiredParameter, .exceedsPlatformLimits:
            return true
        case .unsupportedHardware, .sensorUnavailable:
            return false
        }
    }
    
    /// Severity level of the error
    public var severity: ErrorSeverity {
        switch self {
        case .unsupportedHardware, .sensorUnavailable:
            return .critical
        case .cameraPermissionDenied:
            return .high
        case .invalidConfidence, .invalidDistance, .invalidBallDiameter:
            return .medium
        case .invalidFrameRate, .invalidLatency, .invalidGPUUsage:
            return .medium
        case .invalidParameterCombination, .missingRequiredParameter, .exceedsPlatformLimits:
            return .low
        }
    }
    
    /// Category of the error for filtering and handling
    public var category: ErrorCategory {
        switch self {
        case .invalidConfidence, .invalidDistance, .invalidBallDiameter, .invalidFrameRate, .invalidLatency, .invalidGPUUsage:
            return .validation
        case .unsupportedHardware, .sensorUnavailable:
            return .hardware
        case .cameraPermissionDenied:
            return .permissions
        case .invalidParameterCombination, .missingRequiredParameter, .exceedsPlatformLimits:
            return .configuration
        }
    }
}

/// Error severity levels
public enum ErrorSeverity {
    case low        // Warning level - app can continue with degraded functionality
    case medium     // Error level - feature may not work properly
    case high       // Critical error - major functionality affected
    case critical   // Fatal error - app cannot continue
}

/// Error categories for organization and handling
public enum ErrorCategory {
    case validation     // Input validation failures
    case hardware      // Device capability issues
    case permissions   // User permission issues
    case configuration // Setup and configuration issues
}

// MARK: - Error Creation Helpers

extension ConfigurationError {
    
    /// Creates a configuration error for parameter combinations
    /// - Parameter description: Description of the invalid combination
    /// - Returns: ConfigurationError with combination details
    public static func invalidCombination(_ description: String) -> ConfigurationError {
        return .invalidParameterCombination(description)
    }
    
    /// Creates a configuration error for missing parameters
    /// - Parameter parameter: Name of the missing parameter
    /// - Returns: ConfigurationError with parameter details
    public static func missingParameter(_ parameter: String) -> ConfigurationError {
        return .missingRequiredParameter(parameter)
    }
}