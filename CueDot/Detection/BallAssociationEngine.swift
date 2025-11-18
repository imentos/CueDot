import Foundation
import ARKit

/// Advanced ball association and tracking system for maintaining ball identity across frames
/// Handles ball persistence, tracking, and identity management in dynamic scenes
public class BallAssociationEngine {
    
    // MARK: - Configuration
    
    public struct AssociationConfiguration {
        /// Maximum distance a ball can move between frames to maintain identity
        public let maxMovementDistance: Float
        
        /// Maximum time interval for considering ball associations
        public let maxTimeInterval: TimeInterval
        
        /// Minimum confidence threshold for accepting ball associations
        public let minAssociationConfidence: Float
        
        /// Number of frames to keep in history for tracking
        public let trackingHistorySize: Int
        
        /// Distance weight in association scoring
        public let distanceWeight: Float
        
        /// Appearance similarity weight in association scoring
        public let appearanceWeight: Float
        
        /// Temporal consistency weight in association scoring
        public let temporalWeight: Float
        
        public init(
            maxMovementDistance: Float = 0.3,        // 30cm max movement per frame
            maxTimeInterval: TimeInterval = 0.5,     // 500ms max gap
            minAssociationConfidence: Float = 0.6,
            trackingHistorySize: Int = 10,
            distanceWeight: Float = 0.5,
            appearanceWeight: Float = 0.3,
            temporalWeight: Float = 0.2
        ) {
            self.maxMovementDistance = maxMovementDistance
            self.maxTimeInterval = maxTimeInterval
            self.minAssociationConfidence = minAssociationConfidence
            self.trackingHistorySize = trackingHistorySize
            self.distanceWeight = distanceWeight
            self.appearanceWeight = appearanceWeight
            self.temporalWeight = temporalWeight
        }
    }
    
    // MARK: - Data Structures
    
    public struct TrackedBall: Identifiable {
        public let id: UUID
        public let trackingId: String          // Persistent ID across frames
        public var detectionHistory: [EnhancedBallDetectionResult]
        public var predictedPosition: SIMD3<Float>
        public var velocity: SIMD3<Float>
        public var confidence: Float
        public var lastSeenTime: TimeInterval
        public var trackingState: TrackingState
        public let createdTime: TimeInterval
        
        public enum TrackingState {
            case active         // Currently being tracked
            case predicted      // Position predicted based on history
            case lost           // Not seen for several frames
            case confirmed      // High confidence tracking
        }
        
        public var currentDetection: EnhancedBallDetectionResult? {
            return detectionHistory.last
        }
        
        public var isActive: Bool {
            return trackingState == .active || trackingState == .confirmed
        }
        
        public init(from detection: EnhancedBallDetectionResult, trackingId: String) {
            self.id = UUID()
            self.trackingId = trackingId
            self.detectionHistory = [detection]
            self.predictedPosition = detection.center3D
            self.velocity = SIMD3<Float>(0, 0, 0)
            self.confidence = detection.confidence
            self.lastSeenTime = CFAbsoluteTimeGetCurrent()
            self.trackingState = .active
            self.createdTime = CFAbsoluteTimeGetCurrent()
        }
        
        public mutating func update(with detection: EnhancedBallDetectionResult) {
            // Calculate velocity if we have previous position
            if let lastDetection = detectionHistory.last {
                let timeDelta = detection.timestamp - lastDetection.timestamp
                if timeDelta > 0 {
                    let displacement = detection.center3D - lastDetection.center3D
                    velocity = displacement / Float(timeDelta)
                }
            }
            
            detectionHistory.append(detection)
            predictedPosition = detection.center3D
            lastSeenTime = CFAbsoluteTimeGetCurrent()
            trackingState = .active
            
            // Update confidence based on tracking consistency
            updateConfidence()
        }
        
        private mutating func updateConfidence() {
            let recentDetections = Array(detectionHistory.suffix(5))
            let avgConfidence = recentDetections.map { $0.confidence }.reduce(0, +) / Float(recentDetections.count)
            
            // Factor in tracking stability
            let stabilityFactor = calculateStabilityFactor()
            confidence = (avgConfidence * 0.7) + (stabilityFactor * 0.3)
        }
        
        private func calculateStabilityFactor() -> Float {
            guard detectionHistory.count >= 3 else { return 0.5 }
            
            let recent = Array(detectionHistory.suffix(3))
            var totalVariation: Float = 0
            
            for i in 1..<recent.count {
                let distance = simd_distance(recent[i].center3D, recent[i-1].center3D)
                totalVariation += distance
            }
            
            let avgVariation = totalVariation / Float(recent.count - 1)
            return max(0, 1.0 - (avgVariation / 0.1))  // Lower variation = higher stability
        }
        
        public mutating func predict(deltaTime: TimeInterval) {
            predictedPosition += velocity * Float(deltaTime)
            trackingState = .predicted
            
            // Reduce confidence over time when predicting
            confidence *= 0.95
        }
    }
    
    public struct AssociationResult {
        public let trackedBalls: [TrackedBall]
        public let newBalls: [EnhancedBallDetectionResult]
        public let lostBalls: [TrackedBall]
        public let associations: [BallAssociation]
        public let frameInfo: FrameInfo
        
        public struct BallAssociation {
            public let trackingId: String
            public let detectionId: UUID
            public let confidence: Float
            public let associationType: AssociationType
            
            public enum AssociationType {
                case direct         // Direct match based on proximity
                case predicted      // Match using velocity prediction
                case recovered      // Ball found after being lost
                case appearance     // Match based on visual similarity
            }
        }
        
        public struct FrameInfo {
            public let timestamp: TimeInterval
            public let processingTime: TimeInterval
            public let totalDetections: Int
            public let activeTrackingIds: Int
            public let newTrackingIds: Int
            public let lostTrackingIds: Int
        }
    }
    
    // MARK: - Properties
    
    private let configuration: AssociationConfiguration
    private var trackedBalls: [String: TrackedBall] = [:]
    private var nextTrackingId: Int = 1
    private let associationMatrix: AssociationMatrix
    private let trackingHistory: TrackingHistory
    
    // MARK: - Initialization
    
    public init(configuration: AssociationConfiguration = AssociationConfiguration()) {
        self.configuration = configuration
        self.associationMatrix = AssociationMatrix(configuration: configuration)
        self.trackingHistory = TrackingHistory(maxSize: configuration.trackingHistorySize)
    }
    
    // MARK: - Public Interface
    
    /// Associate new detections with existing tracked balls
    public func associateBalls(_ detections: [EnhancedBallDetectionResult]) async -> AssociationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Update predictions for existing tracked balls
        updatePredictions(currentTime: currentTime)
        
        // Build association matrix between tracked balls and new detections
        let matrix = await associationMatrix.buildMatrix(
            trackedBalls: Array(trackedBalls.values),
            detections: detections
        )
        
        // Perform optimal assignment using Hungarian algorithm
        let assignments = solveAssignment(matrix: matrix)
        
        // Process assignments and create result
        let result = processAssignments(
            assignments: assignments,
            detections: detections,
            currentTime: currentTime,
            processingTime: CFAbsoluteTimeGetCurrent() - startTime
        )
        
        // Update tracking history
        trackingHistory.addFrame(
            trackedBalls: Array(trackedBalls.values),
            timestamp: currentTime
        )
        
        // Cleanup old or lost balls
        cleanupLostBalls(currentTime: currentTime)
        
        return result
    }
    
    /// Get current state of all tracked balls
    public func getCurrentTrackedBalls() -> [TrackedBall] {
        return Array(trackedBalls.values).sorted { $0.trackingId < $1.trackingId }
    }
    
    /// Reset all tracking data
    public func resetTracking() {
        trackedBalls.removeAll()
        nextTrackingId = 1
        trackingHistory.clear()
    }
    
    /// Get tracking statistics
    public func getTrackingStatistics() -> TrackingStatistics {
        let activeBalls = trackedBalls.values.filter { $0.isActive }
        let avgConfidence = activeBalls.isEmpty ? 0 : 
            activeBalls.map { $0.confidence }.reduce(0, +) / Float(activeBalls.count)
        
        return TrackingStatistics(
            totalTrackedBalls: trackedBalls.count,
            activeBalls: activeBalls.count,
            averageConfidence: avgConfidence,
            averageTrackingDuration: calculateAverageTrackingDuration(),
            historySize: trackingHistory.size
        )
    }
    
    // MARK: - Private Implementation
    
    private func updatePredictions(currentTime: TimeInterval) {
        for (trackingId, ball) in trackedBalls {
            var updatedBall = ball
            let timeSinceLastSeen = currentTime - ball.lastSeenTime
            
            if timeSinceLastSeen > 0.1 && timeSinceLastSeen < configuration.maxTimeInterval {
                updatedBall.predict(deltaTime: timeSinceLastSeen)
            } else if timeSinceLastSeen >= configuration.maxTimeInterval {
                updatedBall.trackingState = .lost
            }
            
            trackedBalls[trackingId] = updatedBall
        }
    }
    
    private func solveAssignment(matrix: AssociationMatrix.Matrix) -> [AssociationMatrix.Assignment] {
        // Simplified assignment algorithm (greedy approach)
        // In production, implement Hungarian algorithm for optimal assignment
        var assignments: [AssociationMatrix.Assignment] = []
        var usedDetections = Set<Int>()
        var usedTracks = Set<Int>()
        
        // Sort potential assignments by confidence (highest first)
        let sortedCells = matrix.cells.sorted { $0.score > $1.score }
        
        for cell in sortedCells {
            guard cell.score >= configuration.minAssociationConfidence,
                  !usedTracks.contains(cell.trackIndex),
                  !usedDetections.contains(cell.detectionIndex) else {
                continue
            }
            
            assignments.append(AssociationMatrix.Assignment(
                trackIndex: cell.trackIndex,
                detectionIndex: cell.detectionIndex,
                confidence: cell.score
            ))
            
            usedTracks.insert(cell.trackIndex)
            usedDetections.insert(cell.detectionIndex)
        }
        
        return assignments
    }
    
    private func processAssignments(
        assignments: [AssociationMatrix.Assignment],
        detections: [EnhancedBallDetectionResult],
        currentTime: TimeInterval,
        processingTime: TimeInterval
    ) -> AssociationResult {
        var associations: [AssociationResult.BallAssociation] = []
        var newBalls: [EnhancedBallDetectionResult] = []
        var lostBalls: [TrackedBall] = []
        var usedDetectionIndices = Set<Int>()
        
        let trackedBallsArray = Array(trackedBalls.values)
        
        // Process successful assignments
        for assignment in assignments {
            let trackingId = trackedBallsArray[assignment.trackIndex].trackingId
            let detection = detections[assignment.detectionIndex]
            
            // Update tracked ball with new detection
            var trackedBall = trackedBalls[trackingId]!
            trackedBall.update(with: detection)
            trackedBalls[trackingId] = trackedBall
            
            associations.append(AssociationResult.BallAssociation(
                trackingId: trackingId,
                detectionId: detection.id,
                confidence: assignment.confidence,
                associationType: determineAssociationType(assignment, trackedBall: trackedBall)
            ))
            
            usedDetectionIndices.insert(assignment.detectionIndex)
        }
        
        // Identify new balls (unassigned detections)
        for (index, detection) in detections.enumerated() {
            guard !usedDetectionIndices.contains(index) else { continue }
            
            // Create new tracked ball
            let newTrackingId = "ball_\(nextTrackingId)"
            nextTrackingId += 1
            
            let newTrackedBall = TrackedBall(from: detection, trackingId: newTrackingId)
            trackedBalls[newTrackingId] = newTrackedBall
            newBalls.append(detection)
            
            associations.append(AssociationResult.BallAssociation(
                trackingId: newTrackingId,
                detectionId: detection.id,
                confidence: detection.confidence,
                associationType: .direct
            ))
        }
        
        // Identify lost balls
        let assignedTrackingIds = Set(assignments.map { 
            trackedBallsArray[$0.trackIndex].trackingId 
        })
        
        for (trackingId, trackedBall) in trackedBalls {
            if !assignedTrackingIds.contains(trackingId) && 
               trackedBall.trackingState != .lost &&
               currentTime - trackedBall.lastSeenTime > configuration.maxTimeInterval {
                lostBalls.append(trackedBall)
            }
        }
        
        let frameInfo = AssociationResult.FrameInfo(
            timestamp: currentTime,
            processingTime: processingTime,
            totalDetections: detections.count,
            activeTrackingIds: trackedBalls.values.filter { $0.isActive }.count,
            newTrackingIds: newBalls.count,
            lostTrackingIds: lostBalls.count
        )
        
        return AssociationResult(
            trackedBalls: Array(trackedBalls.values),
            newBalls: newBalls,
            lostBalls: lostBalls,
            associations: associations,
            frameInfo: frameInfo
        )
    }
    
    private func determineAssociationType(
        _ assignment: AssociationMatrix.Assignment,
        trackedBall: TrackedBall
    ) -> AssociationResult.BallAssociation.AssociationType {
        if trackedBall.trackingState == .lost {
            return .recovered
        } else if trackedBall.trackingState == .predicted {
            return .predicted
        } else if assignment.confidence > 0.8 {
            return .direct
        } else {
            return .appearance
        }
    }
    
    private func cleanupLostBalls(currentTime: TimeInterval) {
        let lostThreshold = configuration.maxTimeInterval * 3
        
        trackedBalls = trackedBalls.filter { _, ball in
            currentTime - ball.lastSeenTime < lostThreshold
        }
    }
    
    private func calculateAverageTrackingDuration() -> TimeInterval {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let durations = trackedBalls.values.map { currentTime - $0.createdTime }
        return durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
    }
    
    // MARK: - Supporting Structures
    
    public struct TrackingStatistics {
        public let totalTrackedBalls: Int
        public let activeBalls: Int
        public let averageConfidence: Float
        public let averageTrackingDuration: TimeInterval
        public let historySize: Int
    }
}

// MARK: - Supporting Classes

private class AssociationMatrix {
    private let configuration: BallAssociationEngine.AssociationConfiguration
    
    init(configuration: BallAssociationEngine.AssociationConfiguration) {
        self.configuration = configuration
    }
    
    struct Matrix {
        let cells: [Cell]
        let trackCount: Int
        let detectionCount: Int
    }
    
    struct Cell {
        let trackIndex: Int
        let detectionIndex: Int
        let score: Float
    }
    
    struct Assignment {
        let trackIndex: Int
        let detectionIndex: Int
        let confidence: Float
    }
    
    func buildMatrix(
        trackedBalls: [BallAssociationEngine.TrackedBall],
        detections: [EnhancedBallDetectionResult]
    ) async -> Matrix {
        var cells: [Cell] = []
        
        for (trackIndex, trackedBall) in trackedBalls.enumerated() {
            for (detectionIndex, detection) in detections.enumerated() {
                let score = calculateAssociationScore(
                    trackedBall: trackedBall,
                    detection: detection
                )
                
                if score >= configuration.minAssociationConfidence {
                    cells.append(Cell(
                        trackIndex: trackIndex,
                        detectionIndex: detectionIndex,
                        score: score
                    ))
                }
            }
        }
        
        return Matrix(
            cells: cells,
            trackCount: trackedBalls.count,
            detectionCount: detections.count
        )
    }
    
    private func calculateAssociationScore(
        trackedBall: BallAssociationEngine.TrackedBall,
        detection: EnhancedBallDetectionResult
    ) -> Float {
        let distance = simd_distance(trackedBall.predictedPosition, detection.center3D)
        
        // Distance score (closer = higher score)
        let distanceScore = max(0, 1.0 - (distance / configuration.maxMovementDistance))
        
        // Appearance score (simplified - in practice, compare visual features)
        let appearanceScore = calculateAppearanceScore(trackedBall: trackedBall, detection: detection)
        
        // Temporal score (consistency over time)
        let temporalScore = calculateTemporalScore(trackedBall: trackedBall, detection: detection)
        
        return (distanceScore * configuration.distanceWeight) +
               (appearanceScore * configuration.appearanceWeight) +
               (temporalScore * configuration.temporalWeight)
    }
    
    private func calculateAppearanceScore(
        trackedBall: BallAssociationEngine.TrackedBall,
        detection: EnhancedBallDetectionResult
    ) -> Float {
        guard let lastDetection = trackedBall.currentDetection else { return 0.5 }
        
        // Compare ball types if available
        if lastDetection.ballType == detection.ballType {
            return 1.0
        } else if lastDetection.ballType == .unknown || detection.ballType == .unknown {
            return 0.7
        } else {
            return 0.1  // Different ball types
        }
    }
    
    private func calculateTemporalScore(
        trackedBall: BallAssociationEngine.TrackedBall,
        detection: EnhancedBallDetectionResult
    ) -> Float {
        // Score based on tracking consistency and confidence
        let trackingConsistency = trackedBall.confidence
        let detectionConfidence = detection.confidence
        
        return (trackingConsistency + detectionConfidence) / 2.0
    }
}

private class TrackingHistory {
    private let maxSize: Int
    private var frames: [HistoryFrame] = []
    
    struct HistoryFrame {
        let timestamp: TimeInterval
        let trackedBalls: [BallAssociationEngine.TrackedBall]
    }
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func addFrame(trackedBalls: [BallAssociationEngine.TrackedBall], timestamp: TimeInterval) {
        let frame = HistoryFrame(timestamp: timestamp, trackedBalls: trackedBalls)
        frames.append(frame)
        
        // Keep only recent frames
        if frames.count > maxSize {
            frames.removeFirst(frames.count - maxSize)
        }
    }
    
    func clear() {
        frames.removeAll()
    }
    
    var size: Int {
        return frames.count
    }
}