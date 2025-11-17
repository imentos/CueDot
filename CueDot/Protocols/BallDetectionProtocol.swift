import Foundation
import CoreVideo
import ARKit
import simd

/// Protocol defining the interface for ball detection algorithms
/// Implementations should handle various detection methods (color-based, shape-based, ML-based)
public protocol BallDetectionProtocol {
    
    // MARK: - Configuration
    
    /// Configuration settings for the detection algorithm
    var configuration: BallDetectionConfiguration { get set }
    
    /// Whether the detector is currently active and processing frames
    var isActive: Bool { get }
    
    // MARK: - Detection Methods
    
    /// Detect balls in a given camera frame
    /// - Parameters:
    ///   - pixelBuffer: The camera frame to analyze
    ///   - cameraTransform: Current camera transform from ARFrame
    ///   - timestamp: Frame timestamp for tracking consistency
    /// - Returns: Array of detected balls, empty if none found
    /// - Throws: BallDetectionError if detection fails
    func detectBalls(in pixelBuffer: CVPixelBuffer, 
                    cameraTransform: simd_float4x4,
                    timestamp: TimeInterval) throws -> [BallDetectionResult]
    
    /// Asynchronous ball detection for non-blocking operation
    /// - Parameters:
    ///   - pixelBuffer: The camera frame to analyze
    ///   - cameraTransform: Current camera transform from ARFrame
    ///   - timestamp: Frame timestamp for tracking consistency
    ///   - completion: Callback with detection results or error
    func detectBallsAsync(in pixelBuffer: CVPixelBuffer,
                         cameraTransform: simd_float4x4,
                         timestamp: TimeInterval,
                         completion: @escaping (Result<[BallDetectionResult], BallDetectionError>) -> Void)
    
    // MARK: - Lifecycle Management
    
    /// Start the detection algorithm
    /// - Throws: BallDetectionError if initialization fails
    func startDetection() throws
    
    /// Stop the detection algorithm and cleanup resources
    func stopDetection()
    
    /// Reset the detector state (clear caches, reset counters)
    func reset()
    
    // MARK: - Performance Monitoring
    
    /// Get current performance metrics for the detector
    /// - Returns: Dictionary containing performance data
    func getPerformanceMetrics() -> [String: Double]
    
    /// Check if the detector meets minimum performance requirements
    /// - Parameter requirements: Performance thresholds to check against
    /// - Returns: True if requirements are met
    func meetsPerformanceRequirements(_ requirements: PerformanceRequirements) -> Bool
}

// MARK: - Configuration Types

/// Configuration for ball detection algorithms
public struct BallDetectionConfiguration {
    
    /// Expected ball diameter in meters (standard pool ball: 57.15mm)
    public let ballDiameter: Double
    
    /// Minimum confidence threshold for valid detections (0.0 - 1.0)
    public let minimumConfidence: Double
    
    /// Maximum number of balls to detect per frame
    public let maxBallsPerFrame: Int
    
    /// Detection region of interest (normalized coordinates 0.0 - 1.0)
    public let regionOfInterest: CGRect
    
    /// Color filtering settings
    public let colorFiltering: ColorFilteringSettings
    
    /// Shape detection settings
    public let shapeDetection: ShapeDetectionSettings
    
    /// Performance optimization settings
    public let performance: DetectionPerformanceSettings
    
    public init(ballDiameter: Double = 0.05715,
                minimumConfidence: Double = 0.7,
                maxBallsPerFrame: Int = 16,
                regionOfInterest: CGRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0),
                colorFiltering: ColorFilteringSettings = ColorFilteringSettings(),
                shapeDetection: ShapeDetectionSettings = ShapeDetectionSettings(),
                performance: DetectionPerformanceSettings = DetectionPerformanceSettings()) {
        self.ballDiameter = ballDiameter
        self.minimumConfidence = minimumConfidence
        self.maxBallsPerFrame = maxBallsPerFrame
        self.regionOfInterest = regionOfInterest
        self.colorFiltering = colorFiltering
        self.shapeDetection = shapeDetection
        self.performance = performance
    }
}

/// Color filtering configuration for ball detection
public struct ColorFilteringSettings {
    /// Enable color-based filtering
    public let enabled: Bool
    
    /// HSV color ranges for different ball colors
    public let colorRanges: [BallColor: HSVRange]
    
    /// Color tolerance for matching (0.0 - 1.0)
    public let colorTolerance: Double
    
    /// Adaptive color adjustment based on lighting
    public let adaptiveAdjustment: Bool
    
    public init(enabled: Bool = true,
                colorRanges: [BallColor: HSVRange] = BallColor.standardColorRanges,
                colorTolerance: Double = 0.15,
                adaptiveAdjustment: Bool = true) {
        self.enabled = enabled
        self.colorRanges = colorRanges
        self.colorTolerance = colorTolerance
        self.adaptiveAdjustment = adaptiveAdjustment
    }
}

/// Shape detection configuration
public struct ShapeDetectionSettings {
    /// Enable circle/sphere detection
    public let circleDetectionEnabled: Bool
    
    /// Minimum circle radius in pixels
    public let minimumRadius: Double
    
    /// Maximum circle radius in pixels
    public let maximumRadius: Double
    
    /// Edge detection threshold
    public let edgeThreshold: Double
    
    /// Hough transform parameters
    public let houghParams: HoughTransformParameters
    
    public init(circleDetectionEnabled: Bool = true,
                minimumRadius: Double = 10.0,
                maximumRadius: Double = 150.0,
                edgeThreshold: Double = 50.0,
                houghParams: HoughTransformParameters = HoughTransformParameters()) {
        self.circleDetectionEnabled = circleDetectionEnabled
        self.minimumRadius = minimumRadius
        self.maximumRadius = maximumRadius
        self.edgeThreshold = edgeThreshold
        self.houghParams = houghParams
    }
}

/// Performance optimization settings for detection
public struct DetectionPerformanceSettings {
    /// Maximum processing time per frame in milliseconds
    public let maxProcessingTime: TimeInterval
    
    /// Frame skip ratio for performance (1 = process every frame, 2 = skip every other frame)
    public let frameSkipRatio: Int
    
    /// Image downscaling factor for faster processing (1.0 = full resolution)
    public let downscaleFactor: Double
    
    /// Enable parallel processing for multi-core optimization
    public let parallelProcessing: Bool
    
    /// GPU acceleration settings
    public let gpuAcceleration: GPUAccelerationSettings
    
    public init(maxProcessingTime: TimeInterval = 0.033, // ~30fps
                frameSkipRatio: Int = 1,
                downscaleFactor: Double = 1.0,
                parallelProcessing: Bool = true,
                gpuAcceleration: GPUAccelerationSettings = GPUAccelerationSettings()) {
        self.maxProcessingTime = maxProcessingTime
        self.frameSkipRatio = frameSkipRatio
        self.downscaleFactor = downscaleFactor
        self.parallelProcessing = parallelProcessing
        self.gpuAcceleration = gpuAcceleration
    }
}

// MARK: - Supporting Types

/// Ball colors with standard HSV ranges
public enum BallColor: String, CaseIterable {
    case white = "white"
    case yellow = "yellow"
    case blue = "blue"
    case red = "red"
    case purple = "purple"
    case orange = "orange"
    case green = "green"
    case brown = "brown"
    case black = "black"
    
    /// Standard color ranges for pool balls
    public static let standardColorRanges: [BallColor: HSVRange] = [
        .white: HSVRange(hMin: 0, hMax: 360, sMin: 0, sMax: 30, vMin: 80, vMax: 100),
        .yellow: HSVRange(hMin: 45, hMax: 65, sMin: 60, sMax: 100, vMin: 60, vMax: 100),
        .blue: HSVRange(hMin: 200, hMax: 240, sMin: 60, sMax: 100, vMin: 30, vMax: 100),
        .red: HSVRange(hMin: 350, hMax: 10, sMin: 60, sMax: 100, vMin: 30, vMax: 100),
        .purple: HSVRange(hMin: 280, hMax: 320, sMin: 60, sMax: 100, vMin: 30, vMax: 100),
        .orange: HSVRange(hMin: 15, hMax: 35, sMin: 60, sMax: 100, vMin: 60, vMax: 100),
        .green: HSVRange(hMin: 90, hMax: 150, sMin: 60, sMax: 100, vMin: 30, vMax: 100),
        .brown: HSVRange(hMin: 15, hMax: 35, sMin: 40, sMax: 80, vMin: 20, vMax: 60),
        .black: HSVRange(hMin: 0, hMax: 360, sMin: 0, sMax: 100, vMin: 0, vMax: 20)
    ]
}

/// HSV color range for filtering
public struct HSVRange {
    public let hMin: Double // Hue minimum (0-360)
    public let hMax: Double // Hue maximum (0-360)
    public let sMin: Double // Saturation minimum (0-100)
    public let sMax: Double // Saturation maximum (0-100)
    public let vMin: Double // Value minimum (0-100)
    public let vMax: Double // Value maximum (0-100)
    
    public init(hMin: Double, hMax: Double, sMin: Double, sMax: Double, vMin: Double, vMax: Double) {
        self.hMin = hMin
        self.hMax = hMax
        self.sMin = sMin
        self.sMax = sMax
        self.vMin = vMin
        self.vMax = vMax
    }
}

/// Hough transform parameters for circle detection
public struct HoughTransformParameters {
    /// Accumulator resolution (higher = more accurate, slower)
    public let accumulatorResolution: Double
    
    /// Minimum distance between circle centers
    public let minDistanceBetweenCircles: Double
    
    /// Upper threshold for edge detection
    public let upperThreshold: Double
    
    /// Accumulator threshold for center detection
    public let accumulatorThreshold: Double
    
    public init(accumulatorResolution: Double = 1.0,
                minDistanceBetweenCircles: Double = 30.0,
                upperThreshold: Double = 100.0,
                accumulatorThreshold: Double = 15.0) {
        self.accumulatorResolution = accumulatorResolution
        self.minDistanceBetweenCircles = minDistanceBetweenCircles
        self.upperThreshold = upperThreshold
        self.accumulatorThreshold = accumulatorThreshold
    }
}

/// GPU acceleration settings
public struct GPUAccelerationSettings {
    /// Enable GPU processing where available
    public let enabled: Bool
    
    /// Preferred Metal device (nil for default)
    public let preferredDevice: String?
    
    /// Maximum GPU memory usage in MB
    public let maxMemoryUsage: Int
    
    public init(enabled: Bool = true,
                preferredDevice: String? = nil,
                maxMemoryUsage: Int = 256) {
        self.enabled = enabled
        self.preferredDevice = preferredDevice
        self.maxMemoryUsage = maxMemoryUsage
    }
}

/// Performance requirements for detection validation
public struct PerformanceRequirements {
    /// Minimum frames per second
    public let minimumFPS: Double
    
    /// Maximum processing latency in milliseconds
    public let maximumLatency: TimeInterval
    
    /// Maximum memory usage in MB
    public let maximumMemoryUsage: Double
    
    /// Maximum CPU usage percentage
    public let maximumCPUUsage: Double
    
    public init(minimumFPS: Double = 24.0,
                maximumLatency: TimeInterval = 0.05,
                maximumMemoryUsage: Double = 100.0,
                maximumCPUUsage: Double = 70.0) {
        self.minimumFPS = minimumFPS
        self.maximumLatency = maximumLatency
        self.maximumMemoryUsage = maximumMemoryUsage
        self.maximumCPUUsage = maximumCPUUsage
    }
}

// MARK: - Error Types

/// Errors that can occur during ball detection
public enum BallDetectionError: Error, LocalizedError, Equatable {
    case initializationFailed(String)
    case invalidPixelBuffer
    case processingTimeout
    case insufficientMemory
    case gpuNotAvailable
    case configurationInvalid(String)
    case detectionFailed(String)
    case detectionNotActive
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Detection initialization failed: \(message)"
        case .invalidPixelBuffer:
            return "Invalid or corrupted pixel buffer provided"
        case .processingTimeout:
            return "Detection processing exceeded maximum allowed time"
        case .insufficientMemory:
            return "Insufficient memory available for detection processing"
        case .gpuNotAvailable:
            return "GPU acceleration requested but not available"
        case .configurationInvalid(let message):
            return "Invalid detection configuration: \(message)"
        case .detectionFailed(let message):
            return "Ball detection failed: \(message)"
        case .detectionNotActive:
            return "Ball detection is not currently active"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "Check device capabilities and restart the detection system"
        case .invalidPixelBuffer:
            return "Ensure camera is properly initialized and providing valid frames"
        case .processingTimeout:
            return "Reduce detection complexity or increase processing time limit"
        case .insufficientMemory:
            return "Close other apps or reduce detection quality settings"
        case .gpuNotAvailable:
            return "Disable GPU acceleration in settings"
        case .configurationInvalid:
            return "Review and correct detection configuration parameters"
        case .detectionFailed:
            return "Check lighting conditions and ball visibility"
        case .detectionNotActive:
            return "Call startDetection() to activate ball detection"
        }
    }
}