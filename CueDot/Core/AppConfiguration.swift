import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Central configuration system for the AR Cue Alignment Coach application
/// Provides type-safe access to all application constants and validation
public struct AppConfiguration {
    
    // MARK: - Detection & Tracking Constants
    
    /// Minimum confidence threshold for considering a ball detection reliable
    /// Value range: 0.0 (no confidence) to 1.0 (maximum confidence)
    /// Specification: 0.85 based on Vision framework tuning
    public static let confidenceThreshold: Float = 0.85
    
    /// Maximum allowed jitter in meters before triggering position freeze
    /// Value: 0.002 meters (2mm) - beyond this indicates unstable tracking
    /// Used for detecting excessive motion or tracking instability
    public static let jitterThreshold: Float = 0.002
    
    /// Exponential moving average alpha parameter for position smoothing
    /// Value range: 0.0 (no smoothing) to 1.0 (no filtering)
    /// Specification: 0.5 provides balanced responsiveness and stability
    public static let emaAlpha: Float = 0.5
    
    // MARK: - Visual Overlay Constants
    
    /// Primary color for the alignment overlay (red)
    /// Specification: #FF0000 (pure red) for high visibility
    /// Platform-independent color representation
    public static let overlayColorComponents: (red: Float, green: Float, blue: Float, alpha: Float) = (1.0, 0.0, 0.0, 0.9)
    
    #if canImport(UIKit)
    /// UIColor representation of the overlay color (iOS/tvOS)
    public static var overlayColor: UIColor {
        return UIColor(
            red: CGFloat(overlayColorComponents.red),
            green: CGFloat(overlayColorComponents.green), 
            blue: CGFloat(overlayColorComponents.blue),
            alpha: CGFloat(overlayColorComponents.alpha)
        )
    }
    #endif
    
    /// Diameter of the center dot as a ratio of ball diameter
    /// Value: 0.06 means dot is 6% of ball size
    /// Provides precise center indication without obscuring the ball
    public static let dotDiameterRatio: Float = 0.06
    
    /// Length of crosshair arms as a ratio of ball diameter  
    /// Value: 0.22 means each arm extends 22% of ball diameter from center
    /// Provides clear alignment reference without excessive visual noise
    public static let crosshairLengthRatio: Float = 0.22
    
    // MARK: - Physical Constants
    
    /// Standard pool ball diameter in meters
    /// Value: 0.057 meters (57mm) - regulation pool ball size
    /// Used for size validation and overlay scaling calculations
    public static let standardBallDiameter: Float = 0.057
    
    // MARK: - Performance Constants
    
    /// Target frame rate for AR rendering and detection
    /// Specification: 60fps for smooth AR experience
    public static let targetFPS: Int = 60
    
    /// Maximum acceptable end-to-end latency in milliseconds
    /// Specification: 60ms maximum, with 25-30ms as ideal target
    public static let maxLatencyMS: Int = 60
    
    /// Ideal target latency in milliseconds for optimal user experience
    /// Specification: 25-30ms range for imperceptible delay
    public static let idealLatencyMS: Int = 30
    
    /// Maximum acceptable GPU usage percentage
    /// Keeps device cool and preserves battery life
    public static let maxGPUUsagePercent: Float = 15.0
    
    // MARK: - Timing Constants
    
    /// Duration in seconds to trigger relight suggestion for poor tracking
    /// Specification: 2 seconds of degraded tracking
    public static let relightTriggerDuration: TimeInterval = 2.0
    
    /// Duration in seconds to show realignment warning
    /// Specification: 5 seconds of poor tracking before warning
    public static let realignWarningDuration: TimeInterval = 5.0
    
    /// Duration in seconds for overlay fade animations
    /// Provides smooth visual transitions
    public static let overlayFadeDuration: TimeInterval = 0.3
    
    // MARK: - Computed Properties
    
    /// Calculated center dot diameter in meters for standard ball
    /// Returns the actual size of the center dot overlay
    public static var standardDotDiameter: Float {
        return standardBallDiameter * dotDiameterRatio
    }
    
    /// Calculated crosshair arm length in meters for standard ball
    /// Returns the length of each crosshair arm from center
    public static var standardCrosshairLength: Float {
        return standardBallDiameter * crosshairLengthRatio
    }
    
    /// Target frame interval for the specified FPS
    /// Returns the time interval between frames in seconds
    public static var targetFrameInterval: TimeInterval {
        return 1.0 / Double(targetFPS)
    }
    
    /// Ideal latency as a TimeInterval for performance monitoring
    /// Converts milliseconds to seconds for timing calculations
    public static var idealLatency: TimeInterval {
        return Double(idealLatencyMS) / 1000.0
    }
    
    /// Maximum latency as a TimeInterval for performance validation
    /// Converts milliseconds to seconds for timing calculations
    public static var maxLatency: TimeInterval {
        return Double(maxLatencyMS) / 1000.0
    }
    
    // MARK: - Validation Methods
    
    /// Validates if a confidence value is within acceptable range
    /// - Parameter confidence: The confidence value to validate (0.0-1.0)
    /// - Returns: True if confidence is valid, false otherwise
    public static func isValidConfidence(_ confidence: Float) -> Bool {
        return confidence >= 0.0 && confidence <= 1.0
    }
    
    /// Validates if a distance measurement is reasonable for pool table context
    /// - Parameter distance: Distance in meters to validate
    /// - Returns: True if distance is reasonable (0.1m to 10m), false otherwise
    public static func isValidDistance(_ distance: Float) -> Bool {
        return distance >= 0.1 && distance <= 10.0
    }
    
    /// Validates if a ball diameter is within acceptable range
    /// - Parameter diameter: Ball diameter in meters to validate
    /// - Returns: True if diameter is reasonable (40mm to 80mm), false otherwise
    public static func isValidBallDiameter(_ diameter: Float) -> Bool {
        let minDiameter: Float = 0.040 // 40mm - smaller balls
        let maxDiameter: Float = 0.080 // 80mm - larger balls
        return diameter >= minDiameter && diameter <= maxDiameter
    }
    
    /// Validates if frame rate is within acceptable range
    /// - Parameter fps: Frame rate to validate
    /// - Returns: True if FPS is reasonable (15-120), false otherwise
    public static func isValidFrameRate(_ fps: Int) -> Bool {
        return fps >= 15 && fps <= 120
    }
    
    /// Validates if latency is within acceptable performance bounds
    /// - Parameter latencyMS: Latency in milliseconds to validate
    /// - Returns: True if latency is acceptable (<100ms), false otherwise
    public static func isValidLatency(_ latencyMS: Int) -> Bool {
        return latencyMS >= 0 && latencyMS <= 100
    }
    
    /// Validates if GPU usage percentage is within acceptable bounds
    /// - Parameter usage: GPU usage percentage to validate
    /// - Returns: True if usage is reasonable (0-50%), false otherwise
    public static func isValidGPUUsage(_ usage: Float) -> Bool {
        return usage >= 0.0 && usage <= 50.0
    }
    
    // MARK: - Configuration Scaling
    
    /// Calculates the appropriate dot diameter for a given ball diameter
    /// - Parameter ballDiameter: The actual ball diameter in meters
    /// - Returns: The calculated dot diameter in meters
    public static func calculateDotDiameter(for ballDiameter: Float) -> Float {
        guard isValidBallDiameter(ballDiameter) else {
            return standardDotDiameter
        }
        return ballDiameter * dotDiameterRatio
    }
    
    /// Calculates the appropriate crosshair length for a given ball diameter
    /// - Parameter ballDiameter: The actual ball diameter in meters
    /// - Returns: The calculated crosshair arm length in meters
    public static func calculateCrosshairLength(for ballDiameter: Float) -> Float {
        guard isValidBallDiameter(ballDiameter) else {
            return standardCrosshairLength
        }
        return ballDiameter * crosshairLengthRatio
    }
    
    /// Calculates distance-based scale factor for overlay sizing
    /// - Parameter distance: Distance from camera to ball in meters
    /// - Returns: Scale factor to maintain consistent visual size (1.0 = no scaling)
    public static func calculateScaleFactor(for distance: Float) -> Float {
        guard isValidDistance(distance) else {
            return 1.0
        }
        
        // Scale inversely with distance to maintain visual consistency
        // Reference distance of 1.5m (typical pool shot distance)
        let referenceDistance: Float = 1.5
        return referenceDistance / distance
    }
}

// MARK: - Configuration Information

extension AppConfiguration {
    
    /// Human-readable description of all configuration values
    /// Useful for debugging and development
    public static var description: String {
        return """
        AR Cue Alignment Coach Configuration:
        
        Detection & Tracking:
        - Confidence Threshold: \(confidenceThreshold)
        - Jitter Threshold: \(jitterThreshold)m (\(jitterThreshold * 1000)mm)
        - EMA Alpha: \(emaAlpha)
        
        Visual Overlay:
        - Overlay Color: RGB(\(overlayColorComponents.red), \(overlayColorComponents.green), \(overlayColorComponents.blue), \(overlayColorComponents.alpha))
        - Dot Diameter Ratio: \(dotDiameterRatio) (\(dotDiameterRatio * 100)%)
        - Crosshair Length Ratio: \(crosshairLengthRatio) (\(crosshairLengthRatio * 100)%)
        
        Physical Constants:
        - Standard Ball Diameter: \(standardBallDiameter)m (\(standardBallDiameter * 1000)mm)
        - Standard Dot Diameter: \(standardDotDiameter)m (\(standardDotDiameter * 1000)mm)
        - Standard Crosshair Length: \(standardCrosshairLength)m (\(standardCrosshairLength * 1000)mm)
        
        Performance Targets:
        - Target FPS: \(targetFPS)
        - Ideal Latency: \(idealLatencyMS)ms
        - Max Latency: \(maxLatencyMS)ms
        - Max GPU Usage: \(maxGPUUsagePercent)%
        
        Timing:
        - Relight Trigger: \(relightTriggerDuration)s
        - Realign Warning: \(realignWarningDuration)s
        - Overlay Fade: \(overlayFadeDuration)s
        """
    }
}