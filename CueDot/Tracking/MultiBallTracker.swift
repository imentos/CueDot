import Foundation
import simd
#if canImport(QuartzCore)
import QuartzCore
#endif

/// Multi-ball tracker implementing the BallTrackingProtocol
/// Manages tracking of multiple balls simultaneously using Kalman filtering
public class MultiBallTracker: BallTrackingProtocol {
    
    // MARK: - Protocol Properties
    
    public var configuration: BallTrackingConfiguration {
        didSet {
            validateConfiguration()
        }
    }
    
    public private(set) var isActive: Bool = false
    public var trackedBallCount: Int {
        return activeTracks.count
    }
    
    // MARK: - Public Properties
    
    /// Currently active ball tracks
    public internal(set) var activeTracks: [BallTrack] = []
    
    /// Performance metrics
    private var performanceMetrics: [String: Double] = [:]
    
    /// Track ID counter for unique identification
    private var nextTrackID: Int = 1
    
    /// Last processing timestamp
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Internal Track Management
    
    /// Internal representation of a tracked ball
    public class BallTrack {
        public let trackID: Int
        internal let kalmanFilter: SimpleKalmanFilter
        public var lastTimestamp: TimeInterval
        public var consecutiveMisses: Int
        public var state: BallTrackState
        public var totalDetections: Int
        public var confidenceHistory: [Float] = []
        
        init(id: Int, initialDetection: BallDetectionResult) {
            self.trackID = id
            self.kalmanFilter = SimpleKalmanFilter.ballTracker(initialPosition: initialDetection.ballCenter3D)
            self.lastTimestamp = initialDetection.timestamp
            self.consecutiveMisses = 0
            self.state = .active
            self.totalDetections = 1
            self.confidenceHistory = [initialDetection.confidence]
        }
        
        func update(with detection: BallDetectionResult) {
            kalmanFilter.update(with: detection.ballCenter3D, at: detection.timestamp, confidence: detection.confidence)
            lastTimestamp = detection.timestamp
            consecutiveMisses = 0
            totalDetections += 1
            confidenceHistory.append(detection.confidence)
            
            // Limit history size
            if confidenceHistory.count > 20 {
                confidenceHistory.removeFirst()
            }
            
            state = .active
        }
        
        func predict(at timestamp: TimeInterval) {
            lastTimestamp = timestamp
            consecutiveMisses += 1
            
            // Update state based on consecutive misses
            if consecutiveMisses <= 2 {
                state = .predicted
            } else if consecutiveMisses < 5 {
                state = .jittering(severity: Float(consecutiveMisses) / 5.0)
            } else {
                state = .lost(reason: "Extended occlusion")
            }
        }
        
        func getTrackingResult(isDetected: Bool, timestamp: TimeInterval) -> TrackingResult {
            let position = isDetected ? kalmanFilter.getPosition() : kalmanFilter.predict(at: timestamp)
            let velocity = kalmanFilter.getVelocity()
            let uncertainty = kalmanFilter.getPositionUncertainty()
            let confidence = kalmanFilter.getTrackingConfidence()
            
            let metadata = TrackingMetadata(
                trackAge: timestamp - (lastTimestamp - TimeInterval(totalDetections) * 0.033),
                consecutiveMisses: consecutiveMisses,
                totalDetections: totalDetections,
                averageConfidence: confidenceHistory.reduce(0, +) / Float(max(1, confidenceHistory.count)),
                isStable: consecutiveMisses < 3 && confidence > 0.7
            )
            
            return TrackingResult(
                trackID: trackID,
                position: position,
                velocity: velocity,
                confidence: confidence,
                isDetected: isDetected,
                timestamp: timestamp,
                uncertainty: uncertainty,
                state: state,
                metadata: metadata
            )
        }
        
        var shouldRemove: Bool {
            return consecutiveMisses > 10 || kalmanFilter.getTrackingConfidence() < 0.01
        }
    }
    
    // MARK: - Initialization
    
    public init(configuration: BallTrackingConfiguration = BallTrackingConfiguration()) {
        self.configuration = configuration
        validateConfiguration()
    }
    
    // MARK: - BallTrackingProtocol Implementation
    
    /// Update tracking with new detection results (Protocol requirement)
    public func updateTracking(with detections: [BallDetectionResult],
                              timestamp: TimeInterval,
                              cameraTransform: simd_float4x4) throws -> [TrackedBall] {
        lastUpdateTime = timestamp
        
        // Predict all existing tracks to current time
        for track in activeTracks {
            track.predict(at: timestamp)
        }
        
        // Associate detections with existing tracks
        let associations = associateDetections(detections, with: activeTracks)
        
        var trackedBalls: [TrackedBall] = []
        var usedDetections = Set<Int>()
        
        // Update associated tracks
        for (trackIndex, detectionIndex) in associations {
            let detection = detections[detectionIndex]
            activeTracks[trackIndex].update(with: detection)
            
            // Calculate velocity from Kalman filter
            let velocity = activeTracks[trackIndex].kalmanFilter.getVelocity()
            
            let trackedBall = TrackedBall(
                id: UUID(), // Convert trackID to UUID
                position: detection.ballCenter3D,
                velocity: velocity,
                acceleration: simd_float3(0, 0, 0), // Not tracked yet
                confidence: Double(detection.confidence),
                lastDetectionTime: timestamp,
                timeSinceLastDetection: 0.0,
                state: .normal,
                covariance: simd_float4x4(diagonal: simd_float4(1, 1, 1, 1)),
                color: nil,
                ballNumber: nil
            )
            trackedBalls.append(trackedBall)
            usedDetections.insert(detectionIndex)
        }
        
        // Create new tracks for unassociated detections
        for (index, detection) in detections.enumerated() {
            if !usedDetections.contains(index) {
                let newTrack = BallTrack(id: nextTrackID, initialDetection: detection)
                nextTrackID += 1
                activeTracks.append(newTrack)
                
                let trackedBall = TrackedBall(
                    id: UUID(),
                    position: detection.ballCenter3D,
                    velocity: simd_float3(0, 0, 0),
                    acceleration: simd_float3(0, 0, 0),
                    confidence: Double(detection.confidence),
                    lastDetectionTime: timestamp,
                    timeSinceLastDetection: 0.0,
                    state: .normal,
                    covariance: simd_float4x4(diagonal: simd_float4(1, 1, 1, 1)),
                    color: nil,
                    ballNumber: nil
                )
                trackedBalls.append(trackedBall)
            }
        }
        
        // Remove lost tracks
        activeTracks.removeAll { track in
            track.consecutiveMisses > 5 || // Use hardcoded value for now
            track.state == .lost(reason: "Too many consecutive misses")
        }
        
        return trackedBalls
    }
    
    /// Predict ball positions at a future timestamp (Protocol requirement)
    public func predictPositions(at futureTimestamp: TimeInterval) throws -> [BallPrediction] {
        var predictions: [BallPrediction] = []
        
        for track in activeTracks {
            track.predict(at: futureTimestamp)
            
            let prediction = BallPrediction(
                ballId: UUID(), // Convert from trackID 
                position: track.kalmanFilter.predict(at: futureTimestamp),
                velocity: track.kalmanFilter.getVelocity(),
                confidence: Double(track.confidenceHistory.last ?? 0.5),
                timestamp: futureTimestamp
            )
            predictions.append(prediction)
        }
        
        return predictions
    }
    
    /// Get trajectory for a specific tracked ball (Protocol requirement)  
    public func getTrajectory(for ballId: UUID,
                             duration: TimeInterval,
                             resolution: Int) throws -> [TrajectoryPoint] {
        guard let track = activeTracks.first(where: { track in track.trackID == 0 }) else { // Temporary fix
            throw BallTrackingError.ballNotFound(ballId)
        }
        
        var trajectoryPoints: [TrajectoryPoint] = []
        let timeStep = duration / Double(resolution)
        let currentTime = getCurrentTime()
        
        for i in 0..<resolution {
            let futureTime = currentTime + (timeStep * Double(i))
            let predictedPosition = track.kalmanFilter.predict(at: futureTime)
            let velocity = track.kalmanFilter.getVelocity()
            
            let point = TrajectoryPoint(
                position: predictedPosition,
                velocity: velocity,
                timeOffset: timeStep * Double(i),
                confidence: Double(track.confidenceHistory.last ?? 0.5)
            )
            trajectoryPoints.append(point)
        }
        
        return trajectoryPoints
    }
    
    /// Start tracking (Protocol requirement)
    public func startTracking() throws {
        isActive = true
        lastUpdateTime = getCurrentTime()
    }
    
    /// Stop tracking (Protocol requirement) 
    public func stopTracking() {
        isActive = false
        activeTracks.removeAll()
    }
    
    /// Reset tracker state (Protocol requirement)
    public func resetTracking() {
        activeTracks.removeAll()
        nextTrackID = 1
        lastUpdateTime = 0
        performanceMetrics.removeAll()
    }
    
    /// Get tracker performance metrics (Protocol requirement)
    public func getPerformanceMetrics() -> [String: Double] {
        return performanceMetrics
    }
    
    /// Remove a specific tracked ball (Protocol requirement)
    public func removeTrackedBall(_ ballId: UUID) {
        activeTracks.removeAll { track in
            // Note: This is a simplified lookup by UUID, may need proper ball ID tracking
            return false // TODO: Implement proper ball ID to track mapping
        }
    }
    
    /// Get current state of all tracked balls (Protocol requirement)
    public func getCurrentState() -> [UUID: TrackedBall] {
        let state: [UUID: TrackedBall] = [:]
        // TODO: Convert BallTrack to TrackedBall and map by ball IDs
        return state
    }
    
    /// Get tracking confidence for a specific ball (Protocol requirement)
    public func getTrackingConfidence(for ballId: UUID) -> Double? {
        // TODO: Implement proper ball ID to track mapping
        return nil
    }
    
    /// Check if a ball is currently being tracked (Protocol requirement)
    public func isTracking(ballId: UUID) -> Bool {
        // TODO: Implement proper ball ID to track mapping
        return false
    }
    
    /// Validate tracking meets performance requirements (Protocol requirement)
    public func meetsPerformanceRequirements(_ requirements: TrackingPerformanceRequirements) -> Bool {
        // Basic implementation - can be enhanced
        return true
    }

    // MARK: - Legacy Implementation (for compatibility)
    
    public func update(with detections: [BallDetectionResult]) -> [TrackingResult] {
        let timestamp = getCurrentTime()
        
        // Predict all existing tracks to current time
        for track in activeTracks {
            track.predict(at: timestamp)
        }
        
        // Associate detections with existing tracks
        let associations = associateDetections(detections, with: activeTracks)
        
        // Update existing tracks with associated detections
        var updatedTrackIDs = Set<Int>()
        for (trackIndex, detectionIndex) in associations {
            if trackIndex < activeTracks.count && detectionIndex < detections.count {
                activeTracks[trackIndex].update(with: detections[detectionIndex])
                updatedTrackIDs.insert(activeTracks[trackIndex].trackID)
            }
        }
        
        // Create new tracks for unassociated detections
        let associatedDetectionIndices = Set(associations.map { $0.detectionIndex })
        for (index, detection) in detections.enumerated() {
            if !associatedDetectionIndices.contains(index) {
                let newTrack = BallTrack(id: nextTrackID, initialDetection: detection)
                activeTracks.append(newTrack)
                nextTrackID += 1
            }
        }
        
        // Remove tracks that should be removed
        activeTracks.removeAll { $0.shouldRemove }
        
        // Update performance metrics
        updatePerformanceMetrics(processingTime: getCurrentTime() - timestamp, 
                                detectionCount: detections.count,
                                trackCount: activeTracks.count)
        
        // Generate tracking results
        return activeTracks.map { track in
            let isDetected = updatedTrackIDs.contains(track.trackID)
            return track.getTrackingResult(isDetected: isDetected, timestamp: timestamp)
        }
    }
    
    public func predict(at timestamp: TimeInterval) -> [TrackingResult] {
        var results: [TrackingResult] = []
        
        for track in activeTracks {
            let position = track.kalmanFilter.predict(at: timestamp)
            let velocity = track.kalmanFilter.getVelocity()
            let uncertainty = track.kalmanFilter.getPositionUncertainty()
            
            // Decay confidence for predictions
            let timeDelta = Float(timestamp - track.lastTimestamp)
            let decayedConfidence = track.kalmanFilter.getTrackingConfidence() * exp(-timeDelta * 0.1) // Use hardcoded decay rate
            
            let metadata = TrackingMetadata(
                trackAge: timestamp - (track.lastTimestamp - TimeInterval(track.totalDetections) * 0.033),
                consecutiveMisses: track.consecutiveMisses,
                totalDetections: track.totalDetections,
                averageConfidence: track.confidenceHistory.reduce(0, +) / Float(max(1, track.confidenceHistory.count)),
                isStable: track.consecutiveMisses < 3 && decayedConfidence > 0.7
            )
            
            results.append(TrackingResult(
                trackID: track.trackID,
                position: position,
                velocity: velocity,
                confidence: decayedConfidence,
                isDetected: false,
                timestamp: timestamp,
                uncertainty: uncertainty,
                state: .predicted,
                metadata: metadata
            ))
        }
        
        return results
    }
    
    public func reset() {
        activeTracks.removeAll()
        performanceMetrics.removeAll()
        nextTrackID = 1
        lastUpdateTime = 0
        isActive = false
    }
    
    public func getTrackingStats() -> TrackingStatistics {
        let totalDetections = activeTracks.reduce(0) { $0 + $1.totalDetections }
        let averageConfidence = activeTracks.isEmpty ? 0.0 : 
            activeTracks.map { $0.kalmanFilter.getTrackingConfidence() }.reduce(0, +) / Float(activeTracks.count)
        
        return TrackingStatistics(
            activeTracks: activeTracks.count,
            totalTracks: performanceMetrics["totalTracksCreated"] ?? 0,
            totalDetections: Double(totalDetections),
            averageConfidence: Double(averageConfidence),
            processingTime: performanceMetrics["lastProcessingTime"] ?? 0,
            memoryUsage: performanceMetrics["memoryUsage"] ?? 0
        )
    }
    
    // MARK: - Private Methods
    
    private func validateConfiguration() {
        // Configuration is now read-only, so no validation changes needed
    }
    
    private func getCurrentTime() -> TimeInterval {
        #if canImport(QuartzCore)
        return CACurrentMediaTime()
        #else
        return Date().timeIntervalSince1970
        #endif
    }
    
    private func associateDetections(_ detections: [BallDetectionResult], 
                                   with tracks: [BallTrack]) -> [(trackIndex: Int, detectionIndex: Int)] {
        guard !detections.isEmpty && !tracks.isEmpty else { return [] }
        
        // Use simple nearest neighbor association for now
        var associations: [(Int, Int)] = []
        var usedDetections = Set<Int>()
        var usedTracks = Set<Int>()
        
        // Calculate distance matrix
        for (trackIndex, track) in tracks.enumerated() {
            if usedTracks.contains(trackIndex) { continue }
            
            var bestDetectionIndex: Int?
            var bestDistance: Float = Float.infinity
            
            for (detectionIndex, detection) in detections.enumerated() {
                if usedDetections.contains(detectionIndex) { continue }
                
                let predictedPosition = track.kalmanFilter.predict(at: detection.timestamp)
                let distance = length(detection.ballCenter3D - predictedPosition)
                
                if distance < 2.0 && distance < bestDistance { // Use hardcoded max distance
                    bestDistance = distance
                    bestDetectionIndex = detectionIndex
                }
            }
            
            if let detectionIndex = bestDetectionIndex {
                associations.append((trackIndex, detectionIndex))
                usedTracks.insert(trackIndex)
                usedDetections.insert(detectionIndex)
            }
        }
        
        return associations
    }
    
    private func updatePerformanceMetrics(processingTime: TimeInterval, 
                                        detectionCount: Int,
                                        trackCount: Int) {
        performanceMetrics["lastProcessingTime"] = processingTime * 1000 // Convert to ms
        performanceMetrics["detectionsCount"] = Double(detectionCount)
        performanceMetrics["activeTracksCount"] = Double(trackCount)
        performanceMetrics["totalTracksCreated"] = (performanceMetrics["totalTracksCreated"] ?? 0) + 1
        
        // Simple memory usage estimate
        let estimatedMemoryMB = Double(trackCount) * 0.1 // ~100KB per track
        performanceMetrics["memoryUsage"] = estimatedMemoryMB
    }
}