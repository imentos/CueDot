import Foundation
import CoreVideo
import simd
import Vision

/// Adaptive parameters that adjust based on environmental conditions
/// Optimizes detection performance for different lighting, distances, and camera settings
public class AdaptiveDetectionParameters {
    
    // MARK: - Core Parameters
    
    /// Maximum image dimension for processing (adjusts based on performance needs)
    public private(set) var maxImageDimension: Int = 1024
    
    /// Contrast adjustment for Vision requests
    public private(set) var contrastAdjustment: Float = 0.0
    
    /// Minimum aspect ratio for ball detection
    public private(set) var minAspectRatio: VNAspectRatio = 0.7
    
    /// Maximum aspect ratio for ball detection
    public private(set) var maxAspectRatio: VNAspectRatio = 1.4
    
    /// Minimum detection size relative to image
    public private(set) var minSize: Float = 0.005
    
    /// Minimum confidence threshold
    public private(set) var minConfidence: VNConfidence = 0.3
    
    /// Minimum shape score for ball candidates
    public private(set) var minShapeScore: Float = 0.4
    
    /// Expected minimum ball area in pixels
    public private(set) var expectedMinBallArea: CGFloat = 100
    
    /// Expected maximum ball area in pixels
    public private(set) var expectedMaxBallArea: CGFloat = 5000
    
    /// Camera field of view factor for depth estimation
    public private(set) var cameraFOVFactor: Double = 0.8
    
    // MARK: - Environmental Factors
    
    /// Current lighting condition assessment
    public private(set) var lightingCondition: LightingCondition = .normal
    
    /// Current estimated camera distance to table
    public private(set) var estimatedCameraDistance: Float = 1.0
    
    /// Image quality assessment
    public private(set) var imageQuality: ImageQuality = .good
    
    /// Motion blur assessment
    public private(set) var motionBlurLevel: MotionBlurLevel = .none
    
    // MARK: - Performance Tracking
    
    private var frameCount: Int = 0
    private var averageProcessingTime: TimeInterval = 0
    private var lightingHistory: [Float] = []
    private var sizeHistory: [Float] = []
    private var confidenceHistory: [Float] = []
    
    // MARK: - Initialization
    
    public init() {
        reset()
    }
    
    // MARK: - Update Methods
    
    /// Update parameters based on current frame analysis
    public func update(
        for pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        cameraTransform: simd_float4x4
    ) {
        frameCount += 1
        
        // Analyze image characteristics
        let imageStats = analyzeImageStatistics(pixelBuffer)
        
        // Update lighting assessment
        updateLightingCondition(imageStats.brightness, contrast: imageStats.contrast)
        
        // Update image quality assessment
        updateImageQuality(imageStats)
        
        // Update motion blur assessment
        updateMotionBlur(imageStats.sharpness)
        
        // Estimate camera distance from transform
        updateCameraDistance(cameraTransform)
        
        // Adapt parameters based on conditions
        adaptParametersToConditions()
        
        // Update history for temporal analysis
        updateHistory(imageStats)
    }
    
    // MARK: - Parameter Adaptation
    
    private func adaptParametersToConditions() {
        // Adjust contrast based on lighting
        switch lightingCondition {
        case .dark:
            contrastAdjustment = 0.3
            minConfidence = 0.2 // Lower threshold in dark conditions
            maxImageDimension = 512 // Reduce for performance
            
        case .bright:
            contrastAdjustment = -0.2
            minConfidence = 0.4 // Higher threshold in bright conditions
            
        case .normal:
            contrastAdjustment = 0.0
            minConfidence = 0.3
            
        case .mixed:
            contrastAdjustment = 0.1
            minConfidence = 0.25
        }
        
        // Adjust size parameters based on estimated distance
        adaptSizeParameters()
        
        // Adjust shape parameters based on image quality
        adaptShapeParameters()
        
        // Adjust processing parameters based on performance
        adaptProcessingParameters()
    }
    
    private func adaptSizeParameters() {
        let distanceFactor = 1.0 / max(0.1, estimatedCameraDistance)
        
        // Closer camera = larger expected ball size
        expectedMinBallArea = CGFloat(80 * distanceFactor)
        expectedMaxBallArea = CGFloat(3000 * distanceFactor)
        
        // Adjust minimum size threshold
        minSize = Float(0.003 / distanceFactor)
    }
    
    private func adaptShapeParameters() {
        switch imageQuality {
        case .excellent:
            minShapeScore = 0.6
            minAspectRatio = 0.75
            maxAspectRatio = 1.33
            
        case .good:
            minShapeScore = 0.5
            minAspectRatio = 0.7
            maxAspectRatio = 1.4
            
        case .fair:
            minShapeScore = 0.4
            minAspectRatio = 0.65
            maxAspectRatio = 1.5
            
        case .poor:
            minShapeScore = 0.3
            minAspectRatio = 0.6
            maxAspectRatio = 1.6
        }
    }
    
    private func adaptProcessingParameters() {
        // Adjust processing parameters based on performance needs
        if averageProcessingTime > 0.1 { // 100ms threshold
            // Reduce processing load
            maxImageDimension = min(512, maxImageDimension)
        } else if averageProcessingTime < 0.03 { // 30ms - we have headroom
            // Can increase quality
            maxImageDimension = min(2048, maxImageDimension + 128)
        }
    }
    
    // MARK: - Environmental Analysis
    
    private func updateLightingCondition(_ brightness: Float, contrast: Float) {
        lightingHistory.append(brightness)
        if lightingHistory.count > 30 { lightingHistory.removeFirst() }
        
        let averageBrightness = lightingHistory.reduce(0, +) / Float(lightingHistory.count)
        
        if averageBrightness < 0.2 {
            lightingCondition = .dark
        } else if averageBrightness > 0.8 {
            lightingCondition = .bright
        } else if contrast < 0.3 {
            lightingCondition = .mixed
        } else {
            lightingCondition = .normal
        }
    }
    
    private func updateImageQuality(_ stats: ImageStatistics) {
        let qualityScore = (stats.sharpness * 0.4 + stats.contrast * 0.3 + stats.clarity * 0.3)
        
        if qualityScore > 0.8 {
            imageQuality = .excellent
        } else if qualityScore > 0.6 {
            imageQuality = .good
        } else if qualityScore > 0.4 {
            imageQuality = .fair
        } else {
            imageQuality = .poor
        }
    }
    
    private func updateMotionBlur(_ sharpness: Float) {
        if sharpness > 0.8 {
            motionBlurLevel = .none
        } else if sharpness > 0.6 {
            motionBlurLevel = .slight
        } else if sharpness > 0.4 {
            motionBlurLevel = .moderate
        } else {
            motionBlurLevel = .severe
        }
    }
    
    private func updateCameraDistance(_ cameraTransform: simd_float4x4) {
        // Extract camera position
        let cameraPosition = simd_float3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // Estimate distance to table (assuming table is at y=0)
        let distanceToTable = abs(cameraPosition.y) + 0.5 // Add offset for typical table height
        
        // Smooth the distance estimate
        estimatedCameraDistance = 0.8 * estimatedCameraDistance + 0.2 * distanceToTable
    }
    
    private func updateHistory(_ stats: ImageStatistics) {
        sizeHistory.append(stats.averageObjectSize)
        confidenceHistory.append(stats.overallConfidence)
        
        // Keep history length manageable
        if sizeHistory.count > 50 { sizeHistory.removeFirst() }
        if confidenceHistory.count > 50 { confidenceHistory.removeFirst() }
    }
    
    // MARK: - Image Analysis
    
    private func analyzeImageStatistics(_ pixelBuffer: CVPixelBuffer) -> ImageStatistics {
        // Lock the pixel buffer for analysis
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return ImageStatistics() // Return default values
        }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Sample pixels for statistical analysis (every 4th pixel for performance)
        var brightness: Float = 0
        var contrast: Float = 0
        var sharpness: Float = 0
        var sampleCount = 0
        
        let step = 4
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4 // Assuming BGRA format
                if offset + 3 < width * height * 4 {
                    let b = Float(buffer[offset])
                    let g = Float(buffer[offset + 1])
                    let r = Float(buffer[offset + 2])
                    
                    let gray = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
                    brightness += gray
                    sampleCount += 1
                    
                    // Calculate local contrast (simplified)
                    if x > 0 && y > 0 {
                        let prevOffset = y * bytesPerRow + (x - step) * 4
                        if prevOffset >= 0 && prevOffset + 3 < width * height * 4 {
                            let prevGray = (Float(buffer[prevOffset + 2]) * 0.299 + 
                                          Float(buffer[prevOffset + 1]) * 0.587 + 
                                          Float(buffer[prevOffset]) * 0.114) / 255.0
                            contrast += abs(gray - prevGray)
                        }
                    }
                }
            }
        }
        
        if sampleCount > 0 {
            brightness /= Float(sampleCount)
            contrast /= Float(sampleCount)
            sharpness = min(contrast * 2.0, 1.0) // Simplified sharpness estimate
        }
        
        return ImageStatistics(
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            clarity: (contrast + sharpness) / 2.0,
            averageObjectSize: estimateAverageObjectSize(),
            overallConfidence: calculateOverallConfidence()
        )
    }
    
    private func estimateAverageObjectSize() -> Float {
        return sizeHistory.isEmpty ? 0.5 : sizeHistory.reduce(0, +) / Float(sizeHistory.count)
    }
    
    private func calculateOverallConfidence() -> Float {
        return confidenceHistory.isEmpty ? 0.5 : confidenceHistory.reduce(0, +) / Float(confidenceHistory.count)
    }
    
    // MARK: - Depth Estimation
    
    /// Estimate depth based on ball diameter in pixels
    public func estimateDepth(ballDiameter: CGFloat) -> Float {
        // Known pool ball diameter: ~57.15mm = 0.05715m
        let realBallDiameter: Float = 0.05715
        
        // Estimate focal length based on image characteristics
        let estimatedFocalLength: Float = 800.0 // Typical smartphone camera
        
        // Depth = (real_size * focal_length) / pixel_size
        let depth = (realBallDiameter * estimatedFocalLength) / Float(ballDiameter)
        
        // Apply distance-based corrections
        let correctedDepth = depth * (1.0 + estimatedCameraDistance * 0.1)
        
        // Clamp to reasonable values
        return max(0.1, min(5.0, correctedDepth))
    }
    
    // MARK: - Public Interface
    
    /// Reset all parameters to defaults
    public func reset() {
        frameCount = 0
        averageProcessingTime = 0
        lightingHistory.removeAll()
        sizeHistory.removeAll()
        confidenceHistory.removeAll()
        
        // Reset to default values
        maxImageDimension = 1024
        contrastAdjustment = 0.0
        minAspectRatio = 0.7
        maxAspectRatio = 1.4
        minSize = 0.005
        minConfidence = 0.3
        minShapeScore = 0.4
        expectedMinBallArea = 100
        expectedMaxBallArea = 5000
        cameraFOVFactor = 0.8
        
        lightingCondition = .normal
        estimatedCameraDistance = 1.0
        imageQuality = .good
        motionBlurLevel = .none
    }
    
    /// Get current metrics for performance monitoring
    public func getMetrics() -> [String: Double] {
        return [
            "adaptive_maxImageDimension": Double(maxImageDimension),
            "adaptive_contrastAdjustment": Double(contrastAdjustment),
            "adaptive_minConfidence": Double(minConfidence),
            "adaptive_estimatedDistance": Double(estimatedCameraDistance),
            "adaptive_lightingCondition": Double(lightingCondition.rawValue),
            "adaptive_imageQuality": Double(imageQuality.rawValue),
            "adaptive_frameCount": Double(frameCount),
            "adaptive_averageProcessingTime": averageProcessingTime * 1000 // ms
        ]
    }
    
    /// Update average processing time for performance adaptation
    public func updateProcessingTime(_ processingTime: TimeInterval) {
        averageProcessingTime = 0.9 * averageProcessingTime + 0.1 * processingTime
    }
}

// MARK: - Supporting Types

public struct ImageStatistics {
    let brightness: Float
    let contrast: Float
    let sharpness: Float
    let clarity: Float
    let averageObjectSize: Float
    let overallConfidence: Float
    
    init(brightness: Float = 0.5,
         contrast: Float = 0.5,
         sharpness: Float = 0.5,
         clarity: Float = 0.5,
         averageObjectSize: Float = 0.5,
         overallConfidence: Float = 0.5) {
        self.brightness = brightness
        self.contrast = contrast
        self.sharpness = sharpness
        self.clarity = clarity
        self.averageObjectSize = averageObjectSize
        self.overallConfidence = overallConfidence
    }
}

public enum LightingCondition: Int, CaseIterable {
    case dark = 0
    case normal = 1
    case bright = 2
    case mixed = 3
}

public enum ImageQuality: Int, CaseIterable {
    case poor = 0
    case fair = 1
    case good = 2
    case excellent = 3
}

public enum MotionBlurLevel: Int, CaseIterable {
    case none = 0
    case slight = 1
    case moderate = 2
    case severe = 3
}