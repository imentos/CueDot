import Foundation
import CoreGraphics
import simd

/// Manages temporal filtering and tracking of ball detections across frames
/// Implements smoothing, prediction, and consistency validation for robust detection
@available(iOS 14.0, macOS 11.0, *)
public class TemporalFilterManager {
    
    // MARK: - Configuration
    
    /// Maximum time window for temporal analysis (seconds)
    private let maxTemporalWindow: TimeInterval = 2.0
    
    /// Minimum track length for stable tracking
    private let minTrackLength: Int = 3
    
    /// Maximum position deviation for track association
    private let maxPositionDeviation: Float = 0.1
    
    /// Minimum confidence for track initialization
    private let minInitializationConfidence: Float = 0.4
    
    /// Confidence decay rate per second
    private let confidenceDecayRate: Float = 0.8
    
    // MARK: - Tracking State
    
    /// Active ball tracks
    private var ballTracks: [BallTrack] = []
    
    /// Next available track ID
    private var nextTrackId: Int = 1
    
    /// Frame counter for performance monitoring
    private var frameCount: Int = 0
    
    /// Performance metrics
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Kalman Filtering
    
    private let kalmanFilterManager = KalmanFilterManager()
    
    // MARK: - Initialization
    
    public init() {
        // Initialize temporal filter manager
    }
    
    // MARK: - Main Processing Interface
    
    /// Process new detections with temporal filtering
    public func processDetections(
        _ detections: [EnhancedVisionBallDetector.CandidateDetection],
        timestamp: TimeInterval
    ) -> [FilteredDetection] {
        frameCount += 1
        let processingStartTime = Date()
        
        // Clean up old tracks
        cleanupOldTracks(timestamp)
        
        // Associate detections with existing tracks
        let (associatedDetections, unassociatedDetections) = associateDetectionsWithTracks(
            detections,
            timestamp: timestamp
        )
        
        // Update existing tracks
        updateExistingTracks(associatedDetections, timestamp: timestamp)
        
        // Initialize new tracks from unassociated detections
        initializeNewTracks(unassociatedDetections, timestamp: timestamp)
        
        // Predict missing detections for active tracks
        predictMissingDetections(timestamp)
        
        // Generate filtered detections
        let filteredDetections = generateFilteredDetections(timestamp)
        
        // Update performance metrics
        updatePerformanceMetrics(processingTime: Date().timeIntervalSince(processingStartTime))
        
        return filteredDetections
    }
    
    // MARK: - Track Association
    
    private func associateDetectionsWithTracks(
        _ detections: [EnhancedVisionBallDetector.CandidateDetection],
        timestamp: TimeInterval
    ) -> (associated: [(track: BallTrack, detection: EnhancedVisionBallDetector.CandidateDetection)], 
          unassociated: [EnhancedVisionBallDetector.CandidateDetection]) {
        
        var associatedPairs: [(track: BallTrack, detection: EnhancedVisionBallDetector.CandidateDetection)] = []
        var unassociatedDetections = detections
        var usedTrackIds: Set<Int> = []
        
        // Use Hungarian algorithm for optimal assignment (simplified version)
        for track in ballTracks.filter({ !$0.isLost }) {
            guard let bestMatch = findBestMatchingDetection(
                for: track,
                in: unassociatedDetections,
                timestamp: timestamp
            ) else { continue }
            
            // Check if this is a valid association
            if isValidAssociation(track: track, detection: bestMatch.detection, cost: bestMatch.cost) {
                associatedPairs.append((track: track, detection: bestMatch.detection))
                usedTrackIds.insert(track.id)
                
                // Remove from unassociated list
                if let index = unassociatedDetections.firstIndex(where: { $0.id == bestMatch.detection.id }) {
                    unassociatedDetections.remove(at: index)
                }
            }
        }
        
        return (associated: associatedPairs, unassociated: unassociatedDetections)
    }
    
    private func findBestMatchingDetection(
        for track: BallTrack,
        in detections: [EnhancedVisionBallDetector.CandidateDetection],
        timestamp: TimeInterval
    ) -> (detection: EnhancedVisionBallDetector.CandidateDetection, cost: Float)? {
        
        let predictedPosition = track.kalmanFilter.predict(timestamp)
        
        var bestMatch: (detection: EnhancedVisionBallDetector.CandidateDetection, cost: Float)?
        
        for detection in detections {
            let cost = calculateAssociationCost(
                predictedPosition: predictedPosition,
                detection: detection,
                track: track,
                timestamp: timestamp
            )
            
            if bestMatch == nil || cost < bestMatch!.cost {
                bestMatch = (detection: detection, cost: cost)
            }
        }
        
        return bestMatch
    }
    
    private func calculateAssociationCost(
        predictedPosition: simd_float2,
        detection: EnhancedVisionBallDetector.CandidateDetection,
        track: BallTrack,
        timestamp: TimeInterval
    ) -> Float {
        
        let detectionPosition = simd_float2(
            Float(detection.boundingBox.midX),
            Float(detection.boundingBox.midY)
        )
        
        // Position distance cost
        let positionDistance = simd_length(detectionPosition - predictedPosition)
        let positionCost = positionDistance * 10.0 // Weight position heavily
        
        // Size difference cost
        let lastSize = track.detectionHistory.last?.boundingBox.area ?? detection.boundingBox.area
        let sizeRatio = Float(detection.boundingBox.area / lastSize)
        let sizeCost = abs(log(sizeRatio)) * 2.0
        
        // Color consistency cost (if available)
        let colorCostValue: Float = calculateColorConsistencyCost(track: track, detection: detection)
        
        // Time gap penalty
        let timeSinceLastUpdate = timestamp - track.lastUpdateTime
        let timeCost = Float(timeSinceLastUpdate) * 5.0
        
        return positionCost + sizeCost + colorCostValue + timeCost
    }
    
    private func calculateColorConsistencyCost(
        track: BallTrack,
        detection: EnhancedVisionBallDetector.CandidateDetection
    ) -> Float {
        // Placeholder for color consistency calculation
        // Would compare detection color with track's established color profile
        return 0.0
    }
    
    private func isValidAssociation(
        track: BallTrack,
        detection: EnhancedVisionBallDetector.CandidateDetection,
        cost: Float
    ) -> Bool {
        // Maximum allowed cost threshold
        let maxCost: Float = 5.0
        return cost <= maxCost
    }
    
    // MARK: - Track Management
    
    private func updateExistingTracks(
        _ associations: [(track: BallTrack, detection: EnhancedVisionBallDetector.CandidateDetection)],
        timestamp: TimeInterval
    ) {
        for (track, detection) in associations {
            track.update(with: detection, timestamp: timestamp)
            performanceMetrics.trackUpdates += 1
        }
    }
    
    private func initializeNewTracks(
        _ detections: [EnhancedVisionBallDetector.CandidateDetection],
        timestamp: TimeInterval
    ) {
        for detection in detections {
            // Only initialize tracks for high-confidence detections
            if detection.confidence >= minInitializationConfidence {
                let newTrack = BallTrack(
                    id: nextTrackId,
                    initialDetection: detection,
                    timestamp: timestamp
                )
                ballTracks.append(newTrack)
                nextTrackId += 1
                performanceMetrics.tracksInitialized += 1
            }
        }
    }
    
    private func predictMissingDetections(_ timestamp: TimeInterval) {
        for track in ballTracks {
            if !track.isLost && timestamp - track.lastUpdateTime > 0.1 { // 100ms threshold
                track.predictForMissingUpdate(timestamp)
            }
        }
    }
    
    private func cleanupOldTracks(_ timestamp: TimeInterval) {
        let maxAge: TimeInterval = maxTemporalWindow
        let lostTrackTimeout: TimeInterval = 1.0
        
        ballTracks.removeAll { track in
            let age = timestamp - track.creationTime
            let timeSinceLastUpdate = timestamp - track.lastUpdateTime
            
            // Remove very old tracks
            if age > maxAge {
                performanceMetrics.tracksExpired += 1
                return true
            }
            
            // Remove lost tracks after timeout
            if track.isLost && timeSinceLastUpdate > lostTrackTimeout {
                performanceMetrics.tracksLost += 1
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Filtered Detection Generation
    
    private func generateFilteredDetections(_ timestamp: TimeInterval) -> [FilteredDetection] {
        var filteredDetections: [FilteredDetection] = []
        
        for track in ballTracks {
            guard let filteredDetection = track.generateFilteredDetection(timestamp) else {
                continue
            }
            
            // Apply temporal smoothing
            let smoothedDetection = applyTemporalSmoothing(filteredDetection, track: track)
            
            // Only include stable tracks with sufficient history
            if track.isStable {
                filteredDetections.append(smoothedDetection)
            }
        }
        
        return filteredDetections
    }
    
    private func applyTemporalSmoothing(
        _ detection: FilteredDetection,
        track: BallTrack
    ) -> FilteredDetection {
        
        // Apply position smoothing using Kalman filter
        let smoothedPosition = track.kalmanFilter.getSmoothedPosition()
        let smoothedSize = calculateSmoothedSize(track)
        
        let smoothedBoundingBox = CGRect(
            x: CGFloat(smoothedPosition.x) - smoothedSize.width / 2,
            y: CGFloat(smoothedPosition.y) - smoothedSize.height / 2,
            width: smoothedSize.width,
            height: smoothedSize.height
        )
        
        // Apply confidence smoothing
        let smoothedConfidence = calculateSmoothedConfidence(track)
        
        return FilteredDetection(
            id: detection.id,
            trackId: track.id,
            boundingBox: smoothedBoundingBox,
            confidence: smoothedConfidence,
            velocity: track.kalmanFilter.getVelocity(),
            predicted: detection.predicted,
            trackAge: track.age,
            stabilityScore: track.stabilityScore,
            colorResult: detection.colorResult,
            timestamp: detection.timestamp
        )
    }
    
    private func calculateSmoothedSize(_ track: BallTrack) -> CGSize {
        let recentDetections = track.detectionHistory.suffix(5)
        
        if recentDetections.isEmpty {
            return CGSize(width: 50, height: 50) // Default size
        }
        
        let averageWidth = recentDetections.map { $0.boundingBox.width }.reduce(0, +) / CGFloat(recentDetections.count)
        let averageHeight = recentDetections.map { $0.boundingBox.height }.reduce(0, +) / CGFloat(recentDetections.count)
        
        return CGSize(width: averageWidth, height: averageHeight)
    }
    
    private func calculateSmoothedConfidence(_ track: BallTrack) -> Float {
        let recentConfidences = track.confidenceHistory.suffix(5)
        
        if recentConfidences.isEmpty {
            return 0.5
        }
        
        // Weighted average with more recent confidences having higher weight
        var weightedSum: Float = 0
        var totalWeight: Float = 0
        
        for (index, confidence) in recentConfidences.enumerated() {
            let weight = Float(index + 1) // More recent = higher weight
            weightedSum += confidence * weight
            totalWeight += weight
        }
        
        return weightedSum / totalWeight
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceMetrics(processingTime: TimeInterval) {
        performanceMetrics.frameCount = frameCount
        performanceMetrics.averageProcessingTime = (
            performanceMetrics.averageProcessingTime * 0.9 + 
            processingTime * 0.1
        )
        performanceMetrics.activeTrackCount = ballTracks.filter { !$0.isLost }.count
    }
    
    // MARK: - Public Interface
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> [String: Double] {
        return [
            "temporal_frameCount": Double(performanceMetrics.frameCount),
            "temporal_activeTrackCount": Double(performanceMetrics.activeTrackCount),
            "temporal_tracksInitialized": Double(performanceMetrics.tracksInitialized),
            "temporal_tracksLost": Double(performanceMetrics.tracksLost),
            "temporal_tracksExpired": Double(performanceMetrics.tracksExpired),
            "temporal_trackUpdates": Double(performanceMetrics.trackUpdates),
            "temporal_averageProcessingTime": performanceMetrics.averageProcessingTime * 1000 // ms
        ]
    }
    
    /// Reset all tracking state
    public func reset() {
        ballTracks.removeAll()
        nextTrackId = 1
        frameCount = 0
        performanceMetrics = PerformanceMetrics()
        kalmanFilterManager.reset()
    }
    
    /// Get current track count
    public var activeTrackCount: Int {
        return ballTracks.filter { !$0.isLost }.count
    }
    
    /// Get track information for debugging
    public func getTrackInfo() -> [(id: Int, position: CGPoint, confidence: Float, age: Int)] {
        return ballTracks.compactMap { track in
            guard let lastDetection = track.detectionHistory.last else { return nil }
            return (
                id: track.id,
                position: lastDetection.boundingBox.center,
                confidence: track.currentConfidence,
                age: track.age
            )
        }
    }
}

// MARK: - Ball Track Class

@available(iOS 14.0, macOS 11.0, *)
private class BallTrack {
    let id: Int
    let creationTime: TimeInterval
    var lastUpdateTime: TimeInterval
    
    var detectionHistory: [EnhancedVisionBallDetector.CandidateDetection] = []
    var confidenceHistory: [Float] = []
    var kalmanFilter: KalmanFilter
    
    var isLost: Bool = false
    var lostFrameCount: Int = 0
    var currentConfidence: Float = 0.5
    
    init(id: Int, initialDetection: EnhancedVisionBallDetector.CandidateDetection, timestamp: TimeInterval) {
        self.id = id
        self.creationTime = timestamp
        self.lastUpdateTime = timestamp
        self.kalmanFilter = KalmanFilter()
        
        update(with: initialDetection, timestamp: timestamp)
    }
    
    func update(with detection: EnhancedVisionBallDetector.CandidateDetection, timestamp: TimeInterval) {
        detectionHistory.append(detection)
        confidenceHistory.append(detection.confidence)
        
        let position = simd_float2(Float(detection.boundingBox.midX), Float(detection.boundingBox.midY))
        kalmanFilter.update(position: position, timestamp: timestamp)
        
        lastUpdateTime = timestamp
        isLost = false
        lostFrameCount = 0
        
        // Update current confidence with temporal decay
        let timeDelta = timestamp - lastUpdateTime
        currentConfidence = detection.confidence * pow(0.95, Float(timeDelta))
        
        // Limit history size
        if detectionHistory.count > 20 {
            detectionHistory.removeFirst()
            confidenceHistory.removeFirst()
        }
    }
    
    func predictForMissingUpdate(_ timestamp: TimeInterval) {
        let _ = kalmanFilter.predict(timestamp)
        lostFrameCount += 1
        
        // Mark as lost if too many consecutive misses
        if lostFrameCount > 5 {
            isLost = true
        }
        
        // Decay confidence
        let timeDelta = timestamp - lastUpdateTime
        currentConfidence *= pow(0.8, Float(timeDelta))
    }
    
    func generateFilteredDetection(_ timestamp: TimeInterval) -> FilteredDetection? {
        guard !detectionHistory.isEmpty else { return nil }
        
        let position = kalmanFilter.getSmoothedPosition()
        let lastDetection = detectionHistory.last!
        
        let boundingBox = CGRect(
            x: CGFloat(position.x) - lastDetection.boundingBox.width / 2,
            y: CGFloat(position.y) - lastDetection.boundingBox.height / 2,
            width: lastDetection.boundingBox.width,
            height: lastDetection.boundingBox.height
        )
        
        return FilteredDetection(
            id: lastDetection.id.uuidString,
            trackId: id,
            boundingBox: boundingBox,
            confidence: currentConfidence,
            velocity: kalmanFilter.getVelocity(),
            predicted: isLost,
            trackAge: age,
            stabilityScore: stabilityScore,
            colorResult: nil, // Would be filled by color analyzer
            timestamp: timestamp
        )
    }
    
    var age: Int {
        return detectionHistory.count
    }
    
    var isStable: Bool {
        return age >= 3 && !isLost
    }
    
    var stabilityScore: Float {
        guard age > 1 else { return 0.0 }
        
        // Calculate position variance
        let positions = detectionHistory.map { 
            simd_float2(Float($0.boundingBox.midX), Float($0.boundingBox.midY))
        }
        
        let meanPosition = positions.reduce(simd_float2(0, 0), +) / Float(positions.count)
        
        let differences = positions.map { $0 - meanPosition }
        let squaredLengths = differences.map { simd_length_squared($0) }
        let variance = squaredLengths.reduce(0, +) / Float(positions.count)
        
        // Lower variance = higher stability
        return max(0.0, 1.0 - sqrt(variance) * 10.0)
    }
}

// MARK: - Kalman Filter Implementation

private class KalmanFilter {
    private var state: simd_float4 // [x, y, vx, vy]
    private var covariance: simd_float4x4
    private var lastTimestamp: TimeInterval?
    
    init() {
        state = simd_float4(0, 0, 0, 0)
        covariance = simd_float4x4(1.0) // Identity matrix
    }
    
    func update(position: simd_float2, timestamp: TimeInterval) {
        if let lastTime = lastTimestamp {
            let dt = Float(timestamp - lastTime)
            predict(dt: dt)
        }
        
        // Update state with measurement
        state.x = position.x
        state.y = position.y
        
        lastTimestamp = timestamp
    }
    
    func predict(_ timestamp: TimeInterval) -> simd_float2 {
        guard let lastTime = lastTimestamp else {
            return simd_float2(state.x, state.y)
        }
        
        let dt = Float(timestamp - lastTime)
        predict(dt: dt)
        
        return simd_float2(state.x, state.y)
    }
    
    private func predict(dt: Float) {
        // Simple constant velocity model
        state.x += state.z * dt // x += vx * dt
        state.y += state.w * dt // y += vy * dt
    }
    
    func getSmoothedPosition() -> simd_float2 {
        return simd_float2(state.x, state.y)
    }
    
    func getVelocity() -> simd_float2 {
        return simd_float2(state.z, state.w)
    }
}

// MARK: - Kalman Filter Manager

private class KalmanFilterManager {
    func reset() {
        // Reset any global Kalman filter state
    }
}

// MARK: - Supporting Types

public struct FilteredDetection {
    public let id: String
    public let trackId: Int
    public let boundingBox: CGRect
    public let confidence: Float
    public let velocity: simd_float2
    public let predicted: Bool
    public let trackAge: Int
    public let stabilityScore: Float
    public let colorResult: BallColorResult?
    public let timestamp: TimeInterval
    
    public var isStable: Bool {
        return trackAge >= 3 && stabilityScore > 0.5
    }
    
    public var isHighConfidence: Bool {
        return confidence > 0.7 && !predicted
    }
}

private struct PerformanceMetrics {
    var frameCount: Int = 0
    var activeTrackCount: Int = 0
    var tracksInitialized: Int = 0
    var tracksLost: Int = 0
    var tracksExpired: Int = 0
    var trackUpdates: Int = 0
    var averageProcessingTime: TimeInterval = 0.0
}

// MARK: - CGRect Extensions

private extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}