import XCTest
import simd
@testable import CueDot

final class MultiBallTrackerTests: XCTestCase {
    
    var tracker: MultiBallTracker!
    var mockDetector: MockBallDetector!
    
    override func setUp() {
        super.setUp()
        tracker = MultiBallTracker()
        mockDetector = MockBallDetector()
    }
    
    override func tearDown() {
        tracker = nil
        mockDetector = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(tracker.activeTracks.count, 0)
        XCTAssertEqual(tracker.getTrackingStats().totalDetections, 0)
    }
    
    // MARK: - Single Ball Tracking Tests
    
    func testTrackSingleBall() {
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(1, 2, 3),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        let tracks = tracker.update(with: [detection])
        
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracker.activeTracks.count, 1)
        
        let track = tracks.first!
        XCTAssertEqual(track.position, detection.position)
        XCTAssertEqual(track.confidence, detection.confidence)
        XCTAssertEqual(track.trackID, tracker.activeTracks.first!.trackID)
    }
    
    func testSingleBallMovement() {
        let positions = [
            simd_float3(0, 0, 0),
            simd_float3(1, 0, 0),
            simd_float3(2, 0, 0),
            simd_float3(3, 0, 0)
        ]
        
        var lastVelocity = simd_float3(0, 0, 0)
        
        for (i, position) in positions.enumerated() {
            let detection = BallDetectionResult(
                id: UUID(),
                position: position,
                confidence: 0.9,
                timestamp: Double(i)
            )
            
            let tracks = tracker.update(with: [detection])
            XCTAssertEqual(tracks.count, 1)
            
            if i > 0 {
                let velocity = tracks.first!.velocity
                XCTAssertGreaterThan(velocity.x, lastVelocity.x) // Learning forward motion
                lastVelocity = velocity
            }
        }
    }
    
    // MARK: - Multiple Ball Tracking Tests
    
    func testTrackMultipleBalls() {
        let detection1 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        let detection2 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(5, 0, 0),
            confidence: 0.8,
            timestamp: 1.0
        )
        
        let tracks = tracker.update(with: [detection1, detection2])
        
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracker.activeTracks.count, 2)
        
        // Tracks should have different IDs
        XCTAssertNotEqual(tracks[0].trackID, tracks[1].trackID)
    }
    
    func testDataAssociation() {
        // First frame: two balls
        let detections1 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.9, timestamp: 1.0)
        ]
        
        let tracks1 = tracker.update(with: detections1)
        XCTAssertEqual(tracks1.count, 2)
        
        let trackID1 = tracks1[0].trackID
        let trackID2 = tracks1[1].trackID
        
        // Second frame: same balls moved slightly
        let detections2 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0.1, 0, 0), confidence: 0.9, timestamp: 2.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5.1, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        let tracks2 = tracker.update(with: detections2)
        XCTAssertEqual(tracks2.count, 2)
        
        // Track IDs should be maintained (closest association)
        let currentTrackIDs = tracks2.map { $0.trackID }
        XCTAssertTrue(currentTrackIDs.contains(trackID1))
        XCTAssertTrue(currentTrackIDs.contains(trackID2))
    }
    
    func testDataAssociationWithCrossingPaths() {
        // Start with two balls at opposite ends
        let detections1 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(10, 0, 0), confidence: 0.9, timestamp: 1.0)
        ]
        
        let tracks1 = tracker.update(with: detections1)
        let leftTrackID = tracks1.first { $0.position.x < 5 }?.trackID
        let rightTrackID = tracks1.first { $0.position.x > 5 }?.trackID
        
        XCTAssertNotNil(leftTrackID)
        XCTAssertNotNil(rightTrackID)
        
        // Move balls towards each other
        let detections2 = [
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.9, timestamp: 2.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        let tracks2 = tracker.update(with: detections2)
        XCTAssertEqual(tracks2.count, 2)
        
        // Should maintain track IDs even when balls are close
        let finalTrackIDs = tracks2.map { $0.trackID }
        XCTAssertTrue(finalTrackIDs.contains(leftTrackID!))
        XCTAssertTrue(finalTrackIDs.contains(rightTrackID!))
    }
    
    // MARK: - Ball Appearance/Disappearance Tests
    
    func testNewBallAppearance() {
        // Start with one ball
        let detection1 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        let tracks1 = tracker.update(with: [detection1])
        XCTAssertEqual(tracks1.count, 1)
        
        // Add a new ball far away
        let detections2 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0.1, 0, 0), confidence: 0.9, timestamp: 2.0),
            BallDetectionResult(id: UUID(), position: simd_float3(20, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        let tracks2 = tracker.update(with: detections2)
        XCTAssertEqual(tracks2.count, 2)
        XCTAssertEqual(tracker.activeTracks.count, 2)
        
        // First ball should maintain its track ID
        let originalTrackID = tracks1.first!.trackID
        let trackIDs = tracks2.map { $0.trackID }
        XCTAssertTrue(trackIDs.contains(originalTrackID))
    }
    
    func testBallDisappearance() {
        let config = BallTrackingConfiguration(
            maxDistance: 2.0,
            maxAge: 5
        )
        tracker = MultiBallTracker(configuration: config)
        
        // Start with two balls
        let detections1 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.9, timestamp: 1.0)
        ]
        
        let tracks1 = tracker.update(with: detections1)
        XCTAssertEqual(tracks1.count, 2)
        
        // Only detect one ball
        let detections2 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0.1, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        let tracks2 = tracker.update(with: detections2)
        
        // Should still track missing ball for a few frames
        XCTAssertEqual(tracker.activeTracks.count, 2)
        XCTAssertEqual(tracks2.count, 2)
        
        // One track should be predicted, one should be detected
        let detectedTracks = tracks2.filter { $0.isDetected }
        let predictedTracks = tracks2.filter { !$0.isDetected }
        
        XCTAssertEqual(detectedTracks.count, 1)
        XCTAssertEqual(predictedTracks.count, 1)
    }
    
    func testOldTrackRemoval() {
        let config = BallTrackingConfiguration(
            maxDistance: 2.0,
            maxAge: 3
        )
        tracker = MultiBallTracker(configuration: config)
        
        // Create a track
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        tracker.update(with: [detection])
        XCTAssertEqual(tracker.activeTracks.count, 1)
        
        // Update several times without detections
        for i in 2...5 {
            tracker.update(with: [])
            
            if i <= 4 { // maxAge = 3, so should survive until frame 4
                XCTAssertEqual(tracker.activeTracks.count, 1)
            } else {
                XCTAssertEqual(tracker.activeTracks.count, 0)
            }
        }
    }
    
    // MARK: - Prediction Tests
    
    func testPrediction() {
        // Establish track with velocity
        let detections = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(1, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        for detection in detections {
            tracker.update(with: [detection])
        }
        
        // Predict future position
        let prediction = tracker.predict(at: 3.0)
        XCTAssertEqual(prediction.count, 1)
        
        let predictedTrack = prediction.first!
        XCTAssertGreaterThan(predictedTrack.position.x, 1.0) // Should predict forward motion
        XCTAssertLessThan(predictedTrack.confidence, 0.9) // Confidence should decay
    }
    
    func testPredictionConfidenceDecay() {
        // Establish track
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        tracker.update(with: [detection])
        
        // Predict at increasing time intervals
        let prediction1 = tracker.predict(at: 1.1)
        let prediction2 = tracker.predict(at: 2.0)
        let prediction3 = tracker.predict(at: 10.0)
        
        XCTAssertEqual(prediction1.count, 1)
        XCTAssertEqual(prediction2.count, 1)
        XCTAssertEqual(prediction3.count, 1)
        
        // Confidence should decrease with time
        XCTAssertGreaterThan(prediction1.first!.confidence, prediction2.first!.confidence)
        XCTAssertGreaterThan(prediction2.first!.confidence, prediction3.first!.confidence)
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() {
        let config = BallTrackingConfiguration(
            maxDistance: 5.0,
            maxAge: 10,
            confidenceDecayRate: 0.8
        )
        
        tracker = MultiBallTracker(configuration: config)
        
        // Test that configuration is respected
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        tracker.update(with: [detection])
        
        // Update without detections for longer than default maxAge
        for i in 2...8 {
            tracker.update(with: [])
        }
        
        // Track should still exist due to higher maxAge
        XCTAssertEqual(tracker.activeTracks.count, 1)
    }
    
    func testMaxDistanceConfiguration() {
        let config = BallTrackingConfiguration(
            maxDistance: 1.0, // Very small distance
            maxAge: 5
        )
        
        tracker = MultiBallTracker(configuration: config)
        
        // Create track
        let detection1 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        tracker.update(with: [detection1])
        
        // Try to associate with detection far away
        let detection2 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(5, 0, 0), // Beyond maxDistance
            confidence: 0.9,
            timestamp: 2.0
        )
        
        let tracks = tracker.update(with: [detection2])
        
        // Should create new track instead of associating
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracker.activeTracks.count, 2)
    }
    
    // MARK: - Statistics Tests
    
    func testTrackingStatistics() {
        let initialStats = tracker.getTrackingStats()
        XCTAssertEqual(initialStats.totalDetections, 0)
        XCTAssertEqual(initialStats.activeTracks, 0)
        XCTAssertEqual(initialStats.totalTracks, 0)
        
        // Add some detections
        let detections = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.8, timestamp: 1.0)
        ]
        
        tracker.update(with: detections)
        
        let stats = tracker.getTrackingStats()
        XCTAssertEqual(stats.totalDetections, 2)
        XCTAssertEqual(stats.activeTracks, 2)
        XCTAssertEqual(stats.totalTracks, 2)
        XCTAssertGreaterThan(stats.averageConfidence, 0)
    }
    
    func testStatisticsAccumulation() {
        // Add detections over multiple frames
        for i in 0..<5 {
            let detection = BallDetectionResult(
                id: UUID(),
                position: simd_float3(Float(i), 0, 0),
                confidence: 0.9,
                timestamp: Double(i)
            )
            
            tracker.update(with: [detection])
        }
        
        let stats = tracker.getTrackingStats()
        XCTAssertEqual(stats.totalDetections, 5)
        XCTAssertEqual(stats.activeTracks, 1)
        XCTAssertEqual(stats.totalTracks, 1)
        XCTAssertEqual(stats.averageConfidence, 0.9, accuracy: 0.1)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Create some tracks
        let detections = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.9, timestamp: 1.0)
        ]
        
        tracker.update(with: detections)
        XCTAssertEqual(tracker.activeTracks.count, 2)
        
        tracker.reset()
        
        XCTAssertEqual(tracker.activeTracks.count, 0)
        
        let stats = tracker.getTrackingStats()
        XCTAssertEqual(stats.totalDetections, 0)
        XCTAssertEqual(stats.activeTracks, 0)
        XCTAssertEqual(stats.totalTracks, 0)
    }
    
    // MARK: - Track ID Management Tests
    
    func testUniqueTrackIDs() {
        let detections = Array(0..<10).map { i in
            BallDetectionResult(
                id: UUID(),
                position: simd_float3(Float(i * 5), 0, 0), // Spread out to avoid association
                confidence: 0.9,
                timestamp: 1.0
            )
        }
        
        let tracks = tracker.update(with: detections)
        
        let trackIDs = tracks.map { $0.trackID }
        let uniqueTrackIDs = Set(trackIDs)
        
        XCTAssertEqual(trackIDs.count, uniqueTrackIDs.count) // All IDs should be unique
    }
    
    func testTrackIDPersistence() {
        // Create track
        let detection1 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 1.0
        )
        
        let tracks1 = tracker.update(with: [detection1])
        let originalTrackID = tracks1.first!.trackID
        
        // Update same ball multiple times
        for i in 2...10 {
            let detection = BallDetectionResult(
                id: UUID(),
                position: simd_float3(Float(i) * 0.1, 0, 0),
                confidence: 0.9,
                timestamp: Double(i)
            )
            
            let tracks = tracker.update(with: [detection])
            XCTAssertEqual(tracks.first!.trackID, originalTrackID)
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDetections() {
        // Should handle empty detection list gracefully
        let tracks = tracker.update(with: [])
        XCTAssertEqual(tracks.count, 0)
    }
    
    func testVeryLowConfidenceDetections() {
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.01,
            timestamp: 1.0
        )
        
        let tracks = tracker.update(with: [detection])
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first!.confidence, 0.01)
    }
    
    func testZeroConfidenceDetections() {
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.0,
            timestamp: 1.0
        )
        
        let tracks = tracker.update(with: [detection])
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first!.confidence, 0.0)
    }
    
    func testNegativeTimestamps() {
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: -1.0
        )
        
        // Should handle negative timestamps gracefully
        let tracks = tracker.update(with: [detection])
        XCTAssertEqual(tracks.count, 1)
    }
    
    func testBackwardsTimeflow() {
        // Create track at time 10
        let detection1 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.9,
            timestamp: 10.0
        )
        
        tracker.update(with: [detection1])
        
        // Update with earlier timestamp
        let detection2 = BallDetectionResult(
            id: UUID(),
            position: simd_float3(1, 0, 0),
            confidence: 0.9,
            timestamp: 5.0
        )
        
        // Should handle backwards time gracefully
        let tracks = tracker.update(with: [detection2])
        XCTAssertGreaterThan(tracks.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithManyDetections() {
        let detections = Array(0..<100).map { i in
            BallDetectionResult(
                id: UUID(),
                position: simd_float3(Float(i % 10), Float(i / 10), 0),
                confidence: 0.9,
                timestamp: 1.0
            )
        }
        
        measure {
            _ = tracker.update(with: detections)
        }
    }
    
    func testPerformanceWithManyTracks() {
        // Create many tracks
        for i in 0..<50 {
            let detection = BallDetectionResult(
                id: UUID(),
                position: simd_float3(Float(i * 5), 0, 0),
                confidence: 0.9,
                timestamp: 1.0
            )
            
            tracker.update(with: [detection])
        }
        
        // Now test performance with many existing tracks
        let newDetections = Array(0..<10).map { i in
            BallDetectionResult(
                id: UUID(),
                position: simd_float3(Float(i * 5 + 1), 0, 0),
                confidence: 0.9,
                timestamp: 2.0
            )
        }
        
        measure {
            _ = tracker.update(with: newDetections)
        }
    }
    
    // MARK: - Association Algorithm Tests
    
    func testAssociationAlgorithm() {
        // Test that association algorithm is working correctly
        tracker = MultiBallTracker()
        
        // Create tracks in specific positions
        let detections1 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(2, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(4, 0, 0), confidence: 0.9, timestamp: 1.0)
        ]
        
        let tracks1 = tracker.update(with: detections1)
        let trackIDs = tracks1.map { $0.trackID }
        
        // Move detections slightly (should maintain associations)
        let detections2 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0.1, 0, 0), confidence: 0.9, timestamp: 2.0),
            BallDetectionResult(id: UUID(), position: simd_float3(2.1, 0, 0), confidence: 0.9, timestamp: 2.0),
            BallDetectionResult(id: UUID(), position: simd_float3(4.1, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        let tracks2 = tracker.update(with: detections2)
        let newTrackIDs = tracks2.map { $0.trackID }
        
        // All original track IDs should be preserved
        for trackID in trackIDs {
            XCTAssertTrue(newTrackIDs.contains(trackID))
        }
    }
    
    func testAssociationWithMissingDetection() {
        // Create three tracks
        let detections1 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(5, 0, 0), confidence: 0.9, timestamp: 1.0),
            BallDetectionResult(id: UUID(), position: simd_float3(10, 0, 0), confidence: 0.9, timestamp: 1.0)
        ]
        
        let tracks1 = tracker.update(with: detections1)
        XCTAssertEqual(tracks1.count, 3)
        
        // Only detect two balls (missing middle one)
        let detections2 = [
            BallDetectionResult(id: UUID(), position: simd_float3(0.1, 0, 0), confidence: 0.9, timestamp: 2.0),
            BallDetectionResult(id: UUID(), position: simd_float3(10.1, 0, 0), confidence: 0.9, timestamp: 2.0)
        ]
        
        let tracks2 = tracker.update(with: detections2)
        
        // Should still track all three balls (one predicted)
        XCTAssertEqual(tracks2.count, 3)
        
        let detectedCount = tracks2.filter { $0.isDetected }.count
        let predictedCount = tracks2.filter { !$0.isDetected }.count
        
        XCTAssertEqual(detectedCount, 2)
        XCTAssertEqual(predictedCount, 1)
    }
    
    // MARK: - Confidence Tests
    
    func testConfidenceTracking() {
        let detection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0, 0, 0),
            confidence: 0.7,
            timestamp: 1.0
        )
        
        let tracks = tracker.update(with: [detection])
        XCTAssertEqual(tracks.first!.confidence, 0.7)
        
        // High confidence detection should improve track confidence
        let highConfidenceDetection = BallDetectionResult(
            id: UUID(),
            position: simd_float3(0.1, 0, 0),
            confidence: 0.95,
            timestamp: 2.0
        )
        
        let updatedTracks = tracker.update(with: [highConfidenceDetection])
        XCTAssertGreaterThan(updatedTracks.first!.confidence, 0.7)
    }
}