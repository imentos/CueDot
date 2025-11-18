import Foundation
import Vision
import CoreML
import ARKit

/// Advanced clustering system for multi-ball detection and spatial reasoning
/// Handles complex scenarios with overlapping, occluded, and clustered balls
public class MultiBallClusteringEngine {
    
    // MARK: - Configuration
    
    public struct ClusteringConfiguration {
        /// Maximum distance between balls to be considered in the same cluster
        public let maxClusterDistance: Float
        
        /// Minimum number of balls required to form a cluster
        public let minClusterSize: Int
        
        /// Maximum number of balls expected in a single cluster
        public let maxClusterSize: Int
        
        /// Distance threshold for considering balls as overlapping
        public let overlapThreshold: Float
        
        /// Confidence threshold for accepting clustered detections
        public let clusterConfidenceThreshold: Float
        
        public init(
            maxClusterDistance: Float = 0.15,        // 15cm between balls
            minClusterSize: Int = 2,
            maxClusterSize: Int = 8,                 // Max 8 balls in a cluster
            overlapThreshold: Float = 0.08,          // 8cm overlap threshold
            clusterConfidenceThreshold: Float = 0.6
        ) {
            self.maxClusterDistance = maxClusterDistance
            self.minClusterSize = minClusterSize
            self.maxClusterSize = maxClusterSize
            self.overlapThreshold = overlapThreshold
            self.clusterConfidenceThreshold = clusterConfidenceThreshold
        }
    }
    
    // MARK: - Data Structures
    
    public struct BallCluster: Identifiable {
        public let id: UUID
        public let balls: [EnhancedBallDetectionResult]
        public let centerPosition: SIMD3<Float>
        public let boundingBox: CGRect
        public let confidence: Float
        public let clusterType: ClusterType
        public let spatialRelationships: [SpatialRelationship]
        
        public enum ClusterType {
            case loose          // Balls spread out but related
            case tight          // Balls very close together
            case overlapping    // Some balls partially occluded
            case linear         // Balls in a line formation
            case circular       // Balls arranged in circular pattern
        }
        
        public struct SpatialRelationship {
            public let ballId1: UUID
            public let ballId2: UUID
            public let distance: Float
            public let relationshipType: RelationshipType
            
            public enum RelationshipType {
                case adjacent       // Next to each other
                case overlapping    // Partially occluded
                case touching       // Physical contact
                case separated      // Clear separation
            }
        }
    }
    
    public struct ClusteringResult {
        public let clusters: [BallCluster]
        public let isolatedBalls: [EnhancedBallDetectionResult]
        public let totalBallCount: Int
        public let processingTime: TimeInterval
        public let sceneComplexity: SceneComplexity
        
        public enum SceneComplexity {
            case simple         // Few balls, no overlaps
            case moderate       // Multiple balls, some clustering
            case complex        // Many balls, significant clustering
            case chaotic        // High overlap, difficult to resolve
        }
    }
    
    // MARK: - Properties
    
    private let configuration: ClusteringConfiguration
    private let spatialAnalyzer: SpatialAnalyzer
    private let clusterValidator: ClusterValidator
    
    // MARK: - Initialization
    
    public init(configuration: ClusteringConfiguration = ClusteringConfiguration()) {
        self.configuration = configuration
        self.spatialAnalyzer = SpatialAnalyzer(configuration: configuration)
        self.clusterValidator = ClusterValidator(configuration: configuration)
    }
    
    // MARK: - Public Interface
    
    /// Perform multi-ball clustering on detected balls
    public func clusterBalls(_ detections: [EnhancedBallDetectionResult]) async throws -> ClusteringResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard !detections.isEmpty else {
            return ClusteringResult(
                clusters: [],
                isolatedBalls: [],
                totalBallCount: 0,
                processingTime: 0,
                sceneComplexity: .simple
            )
        }
        
        // Step 1: Spatial analysis and distance matrix computation
        let spatialAnalysis = await spatialAnalyzer.analyzeSpatialRelationships(detections)
        
        // Step 2: Cluster formation using density-based algorithm
        let rawClusters = await formClusters(detections, spatialAnalysis: spatialAnalysis)
        
        // Step 3: Cluster validation and refinement
        let validatedClusters = await clusterValidator.validateClusters(rawClusters, detections: detections)
        
        // Step 4: Identify isolated balls
        let clusteredBallIds = Set(validatedClusters.flatMap { cluster in
            cluster.balls.map { $0.id }
        })
        let isolatedBalls = detections.filter { !clusteredBallIds.contains($0.id) }
        
        // Step 5: Scene complexity analysis
        let sceneComplexity = analyzeSceneComplexity(
            clusters: validatedClusters,
            isolatedBalls: isolatedBalls.toOriginal(),
            totalBalls: detections.count
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return ClusteringResult(
            clusters: validatedClusters,
            isolatedBalls: isolatedBalls,
            totalBallCount: detections.count,
            processingTime: processingTime,
            sceneComplexity: sceneComplexity
        )
    }
    
    // MARK: - Private Implementation
    
    private func formClusters(_ detections: [EnhancedBallDetectionResult], 
                             spatialAnalysis: SpatialAnalysis) async -> [BallCluster] {
        var clusters: [BallCluster] = []
        var unprocessedBalls = Set(detections.map { $0.id })
        
        for detection in detections {
            guard unprocessedBalls.contains(detection.id) else { continue }
            
            // Find nearby balls using density-based clustering (DBSCAN-like)
            let nearbyBalls = findNearbyBalls(
                detection,
                in: detections,
                spatialAnalysis: spatialAnalysis,
                unprocessed: unprocessedBalls
            )
            
            if nearbyBalls.count >= configuration.minClusterSize {
                let cluster = createCluster(from: nearbyBalls, spatialAnalysis: spatialAnalysis)
                clusters.append(cluster)
                
                // Remove processed balls
                nearbyBalls.forEach { unprocessedBalls.remove($0.id) }
            }
        }
        
        return clusters
    }
    
    private func findNearbyBalls(_ centerBall: EnhancedBallDetectionResult,
                                in detections: [EnhancedBallDetectionResult],
                                spatialAnalysis: SpatialAnalysis,
                                unprocessed: Set<UUID>) -> [EnhancedBallDetectionResult] {
        var cluster = [centerBall]
        var candidates = [centerBall]
        var processed = Set<UUID>()
        
        while !candidates.isEmpty {
            let current = candidates.removeFirst()
            processed.insert(current.id)
            
            for detection in detections {
                guard unprocessed.contains(detection.id),
                      !processed.contains(detection.id) else { continue }
                
                let distance = spatialAnalysis.distance(from: current.id, to: detection.id)
                
                if distance <= configuration.maxClusterDistance {
                    cluster.append(detection)
                    candidates.append(detection)
                    processed.insert(detection.id)
                }
            }
        }
        
        return cluster
    }
    
    private func createCluster(from balls: [EnhancedBallDetectionResult], 
                              spatialAnalysis: SpatialAnalysis) -> BallCluster {
        let centerPosition = calculateClusterCenter(balls)
        let boundingBox = calculateClusterBoundingBox(balls)
        let confidence = calculateClusterConfidence(balls, spatialAnalysis: spatialAnalysis)
        let clusterType = determineClusterType(balls, spatialAnalysis: spatialAnalysis)
        let spatialRelationships = createSpatialRelationships(balls, spatialAnalysis: spatialAnalysis)
        
        return BallCluster(
            id: UUID(),
            balls: balls,
            centerPosition: centerPosition,
            boundingBox: boundingBox,
            confidence: confidence,
            clusterType: clusterType,
            spatialRelationships: spatialRelationships
        )
    }
    
    private func calculateClusterCenter(_ balls: [EnhancedBallDetectionResult]) -> SIMD3<Float> {
        let sumPosition = balls.reduce(SIMD3<Float>(0, 0, 0)) { sum, ball in
            sum + ball.center3D
        }
        return sumPosition / Float(balls.count)
    }
    
    private func calculateClusterBoundingBox(_ balls: [EnhancedBallDetectionResult]) -> CGRect {
        guard !balls.isEmpty else { return .zero }
        
        let minX = balls.map { $0.boundingBox.minX }.min()!
        let minY = balls.map { $0.boundingBox.minY }.min()!
        let maxX = balls.map { $0.boundingBox.maxX }.max()!
        let maxY = balls.map { $0.boundingBox.maxY }.max()!
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    private func calculateClusterConfidence(_ balls: [EnhancedBallDetectionResult], 
                                          spatialAnalysis: SpatialAnalysis) -> Float {
        let avgDetectionConfidence = balls.map { $0.confidence }.reduce(0, +) / Float(balls.count)
        let spatialCoherence = spatialAnalysis.calculateCoherence(for: balls.map { $0.id })
        let densityScore = calculateDensityScore(balls)
        
        return (avgDetectionConfidence * 0.5) + (spatialCoherence * 0.3) + (densityScore * 0.2)
    }
    
    private func determineClusterType(_ balls: [EnhancedBallDetectionResult], 
                                    spatialAnalysis: SpatialAnalysis) -> BallCluster.ClusterType {
        let avgDistance = spatialAnalysis.averageDistance(for: balls.map { $0.id })
        let maxDistance = spatialAnalysis.maxDistance(for: balls.map { $0.id })
        let arrangement = spatialAnalysis.analyzeArrangement(balls.map { $0.id })
        
        if avgDistance < configuration.overlapThreshold {
            return .overlapping
        } else if maxDistance < configuration.maxClusterDistance * 0.6 {
            return .tight
        } else if arrangement.isLinear {
            return .linear
        } else if arrangement.isCircular {
            return .circular
        } else {
            return .loose
        }
    }
    
    private func createSpatialRelationships(_ balls: [EnhancedBallDetectionResult], 
                                          spatialAnalysis: SpatialAnalysis) -> [BallCluster.SpatialRelationship] {
        var relationships: [BallCluster.SpatialRelationship] = []
        
        for i in 0..<balls.count {
            for j in (i+1)..<balls.count {
                let ball1 = balls[i]
                let ball2 = balls[j]
                let distance = spatialAnalysis.distance(from: ball1.id, to: ball2.id)
                let relationshipType = classifyRelationship(distance: distance)
                
                relationships.append(BallCluster.SpatialRelationship(
                    ballId1: ball1.id,
                    ballId2: ball2.id,
                    distance: distance,
                    relationshipType: relationshipType
                ))
            }
        }
        
        return relationships
    }
    
    private func classifyRelationship(distance: Float) -> BallCluster.SpatialRelationship.RelationshipType {
        if distance < 0.057 {  // Standard pool ball diameter is ~57mm
            return .touching
        } else if distance < configuration.overlapThreshold {
            return .overlapping
        } else if distance < configuration.maxClusterDistance * 0.7 {
            return .adjacent
        } else {
            return .separated
        }
    }
    
    private func calculateDensityScore(_ balls: [EnhancedBallDetectionResult]) -> Float {
        guard balls.count > 1 else { return 1.0 }
        
        let boundingBox = calculateClusterBoundingBox(balls)
        let area = boundingBox.width * boundingBox.height
        let ballArea = Float(balls.count) * Float.pi * pow(0.0285, 2)  // Pool ball radius ~28.5mm
        
        return min(1.0, Float(ballArea) / Float(area))
    }
    
    private func analyzeSceneComplexity(clusters: [BallCluster], 
                                      isolatedBalls: [BallDetectionResult],
                                      totalBalls: Int) -> ClusteringResult.SceneComplexity {
        let clusterCount = clusters.count
        let maxClusterSize = clusters.map { $0.balls.count }.max() ?? 0
        let overlappingClusters = clusters.filter { $0.clusterType == .overlapping }.count
        
        if totalBalls <= 3 && clusterCount == 0 {
            return .simple
        } else if totalBalls <= 8 && overlappingClusters <= 1 && maxClusterSize <= 4 {
            return .moderate
        } else if overlappingClusters > 2 || maxClusterSize > 6 {
            return .chaotic
        } else {
            return .complex
        }
    }
}

// MARK: - Supporting Classes

private class SpatialAnalyzer {
    private let configuration: MultiBallClusteringEngine.ClusteringConfiguration
    private var distanceMatrix: [UUID: [UUID: Float]] = [:]
    
    init(configuration: MultiBallClusteringEngine.ClusteringConfiguration) {
        self.configuration = configuration
    }
    
    func analyzeSpatialRelationships(_ detections: [EnhancedBallDetectionResult]) async -> SpatialAnalysis {
        // Compute pairwise distances
        for i in 0..<detections.count {
            let ball1 = detections[i]
            distanceMatrix[ball1.id] = [:]
            
            for j in 0..<detections.count {
                let ball2 = detections[j]
                let distance = simd_distance(ball1.center3D, ball2.center3D)
                distanceMatrix[ball1.id]![ball2.id] = distance
            }
        }
        
        return SpatialAnalysis(distanceMatrix: distanceMatrix)
    }
}

private struct SpatialAnalysis {
    let distanceMatrix: [UUID: [UUID: Float]]
    
    func distance(from id1: UUID, to id2: UUID) -> Float {
        return distanceMatrix[id1]?[id2] ?? Float.infinity
    }
    
    func calculateCoherence(for ballIds: [UUID]) -> Float {
        guard ballIds.count > 1 else { return 1.0 }
        
        var totalDistance: Float = 0
        var pairCount = 0
        
        for i in 0..<ballIds.count {
            for j in (i+1)..<ballIds.count {
                totalDistance += distance(from: ballIds[i], to: ballIds[j])
                pairCount += 1
            }
        }
        
        let avgDistance = totalDistance / Float(pairCount)
        return max(0, 1.0 - (avgDistance / 0.5))  // Normalize to 0-1
    }
    
    func averageDistance(for ballIds: [UUID]) -> Float {
        guard ballIds.count > 1 else { return 0 }
        
        var totalDistance: Float = 0
        var pairCount = 0
        
        for i in 0..<ballIds.count {
            for j in (i+1)..<ballIds.count {
                totalDistance += distance(from: ballIds[i], to: ballIds[j])
                pairCount += 1
            }
        }
        
        return totalDistance / Float(pairCount)
    }
    
    func maxDistance(for ballIds: [UUID]) -> Float {
        guard ballIds.count > 1 else { return 0 }
        
        var maxDist: Float = 0
        
        for i in 0..<ballIds.count {
            for j in (i+1)..<ballIds.count {
                let dist = distance(from: ballIds[i], to: ballIds[j])
                maxDist = max(maxDist, dist)
            }
        }
        
        return maxDist
    }
    
    func analyzeArrangement(_ ballIds: [UUID]) -> ArrangementAnalysis {
        // Simplified arrangement analysis
        // TODO: Implement proper linear and circular arrangement detection
        return ArrangementAnalysis(isLinear: false, isCircular: false)
    }
}

private struct ArrangementAnalysis {
    let isLinear: Bool
    let isCircular: Bool
}

private class ClusterValidator {
    private let configuration: MultiBallClusteringEngine.ClusteringConfiguration
    
    init(configuration: MultiBallClusteringEngine.ClusteringConfiguration) {
        self.configuration = configuration
    }
    
    func validateClusters(_ clusters: [MultiBallClusteringEngine.BallCluster], 
                         detections: [EnhancedBallDetectionResult]) async -> [MultiBallClusteringEngine.BallCluster] {
        return clusters.filter { cluster in
            cluster.confidence >= configuration.clusterConfidenceThreshold &&
            cluster.balls.count >= configuration.minClusterSize &&
            cluster.balls.count <= configuration.maxClusterSize
        }
    }
}