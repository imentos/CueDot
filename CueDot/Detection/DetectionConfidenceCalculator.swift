import Foundation
import Vision
import CoreML
import simd

/// Calculates comprehensive confidence scores for ball detections
/// Combines multiple factors including geometric, temporal, and contextual analysis
@available(iOS 14.0, macOS 11.0, *)
public class DetectionConfidenceCalculator {
    
    // MARK: - Configuration
    
    private let geometricWeight: Float = 0.3
    private let temporalWeight: Float = 0.25
    private let colorWeight: Float = 0.2
    private let contextWeight: Float = 0.15
    private let motionWeight: Float = 0.1
    
    // MARK: - Temporal Tracking
    
    private var detectionHistory: [DetectionHistoryEntry] = []
    private var trackingConfidenceDecay: Float = 0.95
    private let maxHistoryLength = 50
    
    // MARK: - Context Analysis
    
    private var sceneAnalyzer: SceneContextAnalyzer
    private var motionAnalyzer: BallMotionAnalyzer
    
    // MARK: - Initialization
    
    public init() {
        self.sceneAnalyzer = SceneContextAnalyzer()
        self.motionAnalyzer = BallMotionAnalyzer()
    }
    
    // MARK: - Main Confidence Calculation
    
    /// Calculate comprehensive confidence score for a ball detection
    public func calculateConfidence(
        for detection: EnhancedVisionBallDetector.CandidateDetection,
        colorResult: BallColorResult,
        adaptiveParams: AdaptiveDetectionParameters,
        cameraTransform: simd_float4x4,
        timestamp: TimeInterval
    ) -> DetectionConfidence {
        
        // 1. Geometric confidence - shape quality and size appropriateness
        let geometricScore = calculateGeometricConfidence(detection)
        
        // 2. Temporal confidence - consistency with previous detections
        let temporalScore = calculateTemporalConfidence(detection, timestamp: timestamp)
        
        // 3. Color confidence - how well the color analysis matches expected ball colors
        let colorScore = calculateColorConfidence(colorResult)
        
        // 4. Context confidence - how well the detection fits the scene context
        let contextScore = calculateContextConfidence(detection, cameraTransform: cameraTransform)
        
        // 5. Motion confidence - movement patterns consistent with pool balls
        let motionScore = calculateMotionConfidence(detection, timestamp: timestamp)
        
        // Combine scores with weights
        let overallScore = (
            geometricScore * geometricWeight +
            temporalScore * temporalWeight +
            colorScore * colorWeight +
            contextScore * contextWeight +
            motionScore * motionWeight
        )
        
        // Apply environmental adjustments
        let environmentallyAdjustedScore = applyEnvironmentalAdjustments(
            score: overallScore,
            adaptiveParams: adaptiveParams,
            detection: detection
        )
        
        // Update tracking history
        updateDetectionHistory(detection, finalScore: environmentallyAdjustedScore, timestamp: timestamp)
        
        return DetectionConfidence(
            overall: environmentallyAdjustedScore,
            geometric: geometricScore,
            temporal: temporalScore,
            color: colorScore,
            context: contextScore,
            motion: motionScore,
            factors: calculateConfidenceFactors(detection, colorResult),
            timestamp: timestamp
        )
    }
    
    // MARK: - Geometric Confidence
    
    private func calculateGeometricConfidence(_ detection: EnhancedVisionBallDetector.CandidateDetection) -> Float {
        var score: Float = 0
        
        // Base confidence from Vision framework
        score += detection.confidence * 0.4
        
        // Shape quality score (using confidence as proxy)
        score += detection.confidence * 0.3
        
        // Size appropriateness - balls should be within expected size range
        let sizeScore = calculateSizeAppropriatenesScore(detection)
        score += sizeScore * 0.2
        
        // Aspect ratio score - balls should be roughly circular
        let aspectRatio = detection.boundingBox.width / detection.boundingBox.height
        let aspectScore = 1.0 - min(1.0, abs(aspectRatio - 1.0)) // Penalty for non-square aspect ratios
        score += Float(aspectScore) * 0.1
        
        return min(1.0, score)
    }
    
    private func calculateSizeAppropriatenesScore(_ detection: EnhancedVisionBallDetector.CandidateDetection) -> Float {
        let area = detection.boundingBox.width * detection.boundingBox.height
        
        // Expected ball area range (this would be calibrated based on typical distance)
        let minExpectedArea: CGFloat = 0.0005 // Very small balls (far away)
        let maxExpectedArea: CGFloat = 0.05   // Very large balls (close up)
        let idealMinArea: CGFloat = 0.002     // Ideal minimum
        let idealMaxArea: CGFloat = 0.02      // Ideal maximum
        
        if area < minExpectedArea || area > maxExpectedArea {
            return 0.0 // Outside reasonable bounds
        }
        
        if area >= idealMinArea && area <= idealMaxArea {
            return 1.0 // Ideal size
        }
        
        // Gradual falloff outside ideal range
        if area < idealMinArea {
            return Float((area - minExpectedArea) / (idealMinArea - minExpectedArea))
        } else {
            return Float((maxExpectedArea - area) / (maxExpectedArea - idealMaxArea))
        }
    }
    
    // MARK: - Temporal Confidence
    
    private func calculateTemporalConfidence(_ detection: EnhancedVisionBallDetector.CandidateDetection, timestamp: TimeInterval) -> Float {
        if detectionHistory.isEmpty {
            return 0.5 // Neutral score for first detection
        }
        
        // Find closest historical detection within tracking window
        let trackingWindow: TimeInterval = 1.0
        let recentDetections = detectionHistory.filter { timestamp - $0.timestamp <= trackingWindow }
        
        guard !recentDetections.isEmpty else {
            return 0.3 // Slight penalty for isolated detections
        }
        
        // Find best match based on position similarity
        guard let bestMatch = findBestTemporalMatch(detection, in: recentDetections) else {
            return 0.4
        }
        
        // Calculate position consistency score
        let positionDelta = distance(detection.boundingBox.center, bestMatch.detection.boundingBox.center)
        let positionScore = max(0.0, 1.0 - Float(positionDelta) * 10.0) // Penalty for large movements
        
        // Calculate size consistency score
        let sizeRatio = detection.boundingBox.area / bestMatch.detection.boundingBox.area
        let sizeScore = max(0.0, 1.0 - abs(log(Float(sizeRatio))))
        
        // Calculate confidence trend
        let confidenceTrend = calculateConfidenceTrend(bestMatch)
        
        let positionScoreWeight: Float = 0.5
        let sizeScoreWeight: Float = 0.3
        let confidenceTrendWeight: Float = 0.2
        
        return (positionScore * positionScoreWeight + 
                sizeScore * sizeScoreWeight + 
                confidenceTrend * confidenceTrendWeight)
    }
    
    private func findBestTemporalMatch(
        _ detection: EnhancedVisionBallDetector.CandidateDetection,
        in history: [DetectionHistoryEntry]
    ) -> DetectionHistoryEntry? {
        return history.min { entry1, entry2 in
            let dist1 = distance(detection.boundingBox.center, entry1.detection.boundingBox.center)
            let dist2 = distance(detection.boundingBox.center, entry2.detection.boundingBox.center)
            return dist1 < dist2
        }
    }
    
    private func calculateConfidenceTrend(_ historyEntry: DetectionHistoryEntry) -> Float {
        // Look at confidence trend over recent history
        let recentEntries = detectionHistory.suffix(10)
        guard recentEntries.count > 1 else { return 0.5 }
        
        let confidences = recentEntries.map { $0.finalConfidence }
        let trend = (confidences.last! - confidences.first!) / Float(confidences.count - 1)
        
        // Positive trend boosts confidence, negative trend reduces it
        return 0.5 + trend * 0.5
    }
    
    // MARK: - Color Confidence
    
    private func calculateColorConfidence(_ colorResult: BallColorResult) -> Float {
        // Base color analysis confidence
        var score = colorResult.confidence
        
        // Bonus for identifying specific ball numbers
        if let ballNumber = colorResult.dominantColor?.number, ballNumber >= 0 && ballNumber <= 15 {
            score *= 1.1 // 10% bonus for valid ball identification
        }
        
        // Bonus for high color consistency
        if colorResult.hsvStats.colorConsistency > 0.8 {
            score *= 1.05
        }
        
        // Penalty for very low saturation (unless it's black/white balls)
        if colorResult.hsvStats.meanSaturation < 0.3 && 
           !(colorResult.dominantColor?.number == 0 || colorResult.dominantColor?.number == 8) {
            score *= 0.9
        }
        
        return min(1.0, score)
    }
    
    // MARK: - Context Confidence
    
    private func calculateContextConfidence(
        _ detection: EnhancedVisionBallDetector.CandidateDetection,
        cameraTransform: simd_float4x4
    ) -> Float {
        // Analyze scene context
        let sceneScore = sceneAnalyzer.analyzeDetectionContext(detection, cameraTransform: cameraTransform)
        
        // Check for typical pool table characteristics
        let tableScore = analyzePoolTableContext(detection)
        
        // Check for multiple ball consistency
        let multiballScore = analyzeMultiBallConsistency(detection)
        
        let sceneScoreWeight: Float = 0.5
        let tableScoreWeight: Float = 0.3  
        let multiballScoreWeight: Float = 0.2
        
        return (sceneScore * sceneScoreWeight + 
                tableScore * tableScoreWeight + 
                multiballScore * multiballScoreWeight)
    }
    
    private func analyzePoolTableContext(_ detection: EnhancedVisionBallDetector.CandidateDetection) -> Float {
        // Check if detection is on a horizontal surface (table)
        // This would require more scene analysis, but for now we'll use position heuristics
        
        let centerY = detection.boundingBox.midY
        
        // Expect balls to be in the central portion of the image (table area)
        if centerY > 0.2 && centerY < 0.8 {
            return 0.8
        } else if centerY > 0.1 && centerY < 0.9 {
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private func analyzeMultiBallConsistency(_ detection: EnhancedVisionBallDetector.CandidateDetection) -> Float {
        // Check if this detection is consistent with other balls in the scene
        let similarSizedDetections = detectionHistory.filter { entry in
            let sizeRatio = detection.boundingBox.area / entry.detection.boundingBox.area
            return sizeRatio > 0.5 && sizeRatio < 2.0
        }
        
        if similarSizedDetections.count >= 2 {
            return 1.0 // Consistent with multiple balls
        } else if similarSizedDetections.count == 1 {
            return 0.7
        } else {
            return 0.5 // No similar detections
        }
    }
    
    // MARK: - Motion Confidence
    
    private func calculateMotionConfidence(_ detection: EnhancedVisionBallDetector.CandidateDetection, timestamp: TimeInterval) -> Float {
        return motionAnalyzer.analyzeMotion(detection, timestamp: timestamp, history: detectionHistory)
    }
    
    // MARK: - Environmental Adjustments
    
    private func applyEnvironmentalAdjustments(
        score: Float,
        adaptiveParams: AdaptiveDetectionParameters,
        detection: EnhancedVisionBallDetector.CandidateDetection
    ) -> Float {
        var adjustedScore = score
        
        // Lighting condition adjustments
        switch adaptiveParams.lightingCondition {
        case .dark:
            adjustedScore *= 0.9 // Slightly reduced confidence in dark conditions
        case .bright:
            adjustedScore *= 0.95 // Slightly reduced due to potential glare
        case .mixed:
            adjustedScore *= 0.85 // Reduced confidence in mixed lighting
        case .normal:
            break // No adjustment
        }
        
        // Image quality adjustments
        switch adaptiveParams.imageQuality {
        case .excellent:
            adjustedScore *= 1.05
        case .good:
            break // No adjustment
        case .fair:
            adjustedScore *= 0.95
        case .poor:
            adjustedScore *= 0.85
        }
        
        // Motion blur adjustments
        switch adaptiveParams.motionBlurLevel {
        case .none:
            break // No adjustment
        case .slight:
            adjustedScore *= 0.98
        case .moderate:
            adjustedScore *= 0.9
        case .severe:
            adjustedScore *= 0.8
        }
        
        return min(1.0, max(0.0, adjustedScore))
    }
    
    // MARK: - History Management
    
    private func updateDetectionHistory(
        _ detection: EnhancedVisionBallDetector.CandidateDetection,
        finalScore: Float,
        timestamp: TimeInterval
    ) {
        let entry = DetectionHistoryEntry(
            detection: detection,
            finalConfidence: finalScore,
            timestamp: timestamp
        )
        
        detectionHistory.append(entry)
        
        // Apply confidence decay to older entries
        for i in 0..<detectionHistory.count {
            let age = timestamp - detectionHistory[i].timestamp
            let decayFactor = pow(trackingConfidenceDecay, Float(age))
            detectionHistory[i].finalConfidence *= decayFactor
        }
        
        // Remove old entries
        let cutoffTime = timestamp - 5.0 // Keep 5 seconds of history
        detectionHistory = detectionHistory.filter { $0.timestamp > cutoffTime }
        
        // Limit history size
        if detectionHistory.count > maxHistoryLength {
            detectionHistory.removeFirst(detectionHistory.count - maxHistoryLength)
        }
    }
    
    // MARK: - Utility Methods
    
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateConfidenceFactors(
        _ detection: EnhancedVisionBallDetector.CandidateDetection,
        _ colorResult: BallColorResult
    ) -> ConfidenceFactors {
        return ConfidenceFactors(
            shapeQuality: detection.confidence,
            sizeAppropriate: calculateSizeAppropriatenesScore(detection),
            colorConsistency: colorResult.hsvStats.colorConsistency,
            temporalConsistency: detectionHistory.isEmpty ? 0.5 : calculateTemporalConsistency(),
            sceneContext: 0.5, // Placeholder - would need more scene analysis
            motionRealistic: 0.5 // Placeholder - from motion analyzer
        )
    }
    
    private func calculateTemporalConsistency() -> Float {
        guard detectionHistory.count >= 2 else { return 0.5 }
        
        let recentConfidences = detectionHistory.suffix(5).map { $0.finalConfidence }
        let variance = recentConfidences.reduce(0) { sum, conf in
            let mean = recentConfidences.reduce(0, +) / Float(recentConfidences.count)
            return sum + (conf - mean) * (conf - mean)
        } / Float(recentConfidences.count)
        
        return max(0.0, 1.0 - variance)
    }
    
    // MARK: - Public Interface
    
    /// Reset all tracking history
    public func reset() {
        detectionHistory.removeAll()
        motionAnalyzer.reset()
        sceneAnalyzer.reset()
    }
    
    /// Get current tracking statistics
    public func getTrackingStats() -> [String: Double] {
        return [
            "confidence_historyCount": Double(detectionHistory.count),
            "confidence_averageScore": detectionHistory.isEmpty ? 0 : 
                Double(detectionHistory.map { $0.finalConfidence }.reduce(0, +) / Float(detectionHistory.count)),
            "confidence_temporalWeight": Double(temporalWeight),
            "confidence_geometricWeight": Double(geometricWeight)
        ]
    }
}

// MARK: - Supporting Types

public struct DetectionConfidence {
    public let overall: Float
    public let geometric: Float
    public let temporal: Float
    public let color: Float
    public let context: Float
    public let motion: Float
    public let factors: ConfidenceFactors
    public let timestamp: TimeInterval
    
    public var isHighConfidence: Bool {
        return overall > 0.7
    }
    
    public var isValidDetection: Bool {
        return overall > 0.3
    }
}

public struct ConfidenceFactors {
    public let shapeQuality: Float
    public let sizeAppropriate: Float
    public let colorConsistency: Float
    public let temporalConsistency: Float
    public let sceneContext: Float
    public let motionRealistic: Float
}

@available(iOS 14.0, macOS 11.0, *)
private struct DetectionHistoryEntry {
    let detection: EnhancedVisionBallDetector.CandidateDetection
    var finalConfidence: Float
    let timestamp: TimeInterval
}

// MARK: - Scene Context Analyzer

private class SceneContextAnalyzer {
    func analyzeDetectionContext(
        _ detection: EnhancedVisionBallDetector.CandidateDetection,
        cameraTransform: simd_float4x4
    ) -> Float {
        // Placeholder implementation
        // In a real implementation, this would analyze the scene for pool table characteristics
        return 0.6
    }
    
    func reset() {
        // Reset any accumulated scene context
    }
}

// MARK: - Ball Motion Analyzer

private class BallMotionAnalyzer {
    private var velocityHistory: [simd_float2] = []
    
    func analyzeMotion(
        _ detection: EnhancedVisionBallDetector.CandidateDetection,
        timestamp: TimeInterval,
        history: [DetectionHistoryEntry]
    ) -> Float {
        // Analyze motion patterns for realism
        // Pool balls should have smooth, physics-based motion
        
        guard let lastEntry = history.last else { return 0.5 }
        
        let deltaTime = timestamp - lastEntry.timestamp
        guard deltaTime > 0 && deltaTime < 1.0 else { return 0.5 }
        
        // Calculate velocity
        let deltaPosition = simd_float2(
            Float(detection.boundingBox.midX - lastEntry.detection.boundingBox.midX),
            Float(detection.boundingBox.midY - lastEntry.detection.boundingBox.midY)
        )
        
        let velocity = deltaPosition / Float(deltaTime)
        velocityHistory.append(velocity)
        
        if velocityHistory.count > 10 {
            velocityHistory.removeFirst()
        }
        
        // Analyze velocity consistency (smooth motion)
        if velocityHistory.count >= 3 {
            let velocityConsistency = calculateVelocityConsistency()
            return velocityConsistency
        }
        
        return 0.6 // Default score for insufficient motion history
    }
    
    private func calculateVelocityConsistency() -> Float {
        guard velocityHistory.count >= 3 else { return 0.5 }
        
        var accelerations: [Float] = []
        for i in 1..<velocityHistory.count {
            let acceleration = simd_length(velocityHistory[i] - velocityHistory[i-1])
            accelerations.append(acceleration)
        }
        
        // Pool balls should have smooth motion (low acceleration variance)
        let meanAcceleration = accelerations.reduce(0, +) / Float(accelerations.count)
        let variance = accelerations.reduce(0) { sum, acc in
            sum + (acc - meanAcceleration) * (acc - meanAcceleration)
        } / Float(accelerations.count)
        
        // Lower variance = higher consistency score
        return max(0.0, 1.0 - sqrt(variance))
    }
    
    func reset() {
        velocityHistory.removeAll()
    }
}

// MARK: - CGRect Extensions

// MARK: - Extensions

private extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}