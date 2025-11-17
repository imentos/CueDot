import Foundation

/// Performance statistics for ball tracking operations
public struct TrackingStatistics {
    /// Number of currently active tracks
    public let activeTracks: Int
    
    /// Total number of tracks created during session
    public let totalTracks: Double
    
    /// Total number of detections processed
    public let totalDetections: Double
    
    /// Average confidence across all active tracks
    public let averageConfidence: Double
    
    /// Last processing time in milliseconds
    public let processingTime: Double
    
    /// Estimated memory usage in MB
    public let memoryUsage: Double
    
    public init(activeTracks: Int,
               totalTracks: Double,
               totalDetections: Double,
               averageConfidence: Double,
               processingTime: Double,
               memoryUsage: Double) {
        self.activeTracks = activeTracks
        self.totalTracks = totalTracks
        self.totalDetections = totalDetections
        self.averageConfidence = averageConfidence
        self.processingTime = processingTime
        self.memoryUsage = memoryUsage
    }
}

/// Performance statistics for ball detection operations
public struct DetectionStatistics {
    /// Number of balls detected in last frame
    public let ballsDetected: Int
    
    /// Average detection confidence
    public let averageConfidence: Double
    
    /// Processing time for last frame in milliseconds
    public let processingTime: Double
    
    /// Frames per second
    public let fps: Double
    
    /// Total detections processed
    public let totalDetections: Int
    
    /// Memory usage in MB
    public let memoryUsage: Double
    
    public init(ballsDetected: Int,
               averageConfidence: Double,
               processingTime: Double,
               fps: Double,
               totalDetections: Int,
               memoryUsage: Double) {
        self.ballsDetected = ballsDetected
        self.averageConfidence = averageConfidence
        self.processingTime = processingTime
        self.fps = fps
        self.totalDetections = totalDetections
        self.memoryUsage = memoryUsage
    }
}