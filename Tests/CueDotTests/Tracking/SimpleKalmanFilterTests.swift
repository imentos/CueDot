import XCTest
import simd
@testable import CueDot

final class SimpleKalmanFilterTests: XCTestCase {
    
    var kalmanFilter: SimpleKalmanFilter!
    
    override func setUp() {
        super.setUp()
        let initialPosition = simd_float3(0, 0, 0)
        kalmanFilter = SimpleKalmanFilter(initialPosition: initialPosition)
    }
    
    override func tearDown() {
        kalmanFilter = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let initialPos = simd_float3(1, 2, 3)
        let filter = SimpleKalmanFilter(initialPosition: initialPos)
        
        let position = filter.getPosition()
        let velocity = filter.getVelocity()
        
        XCTAssertEqual(position.x, initialPos.x, accuracy: 0.001)
        XCTAssertEqual(position.y, initialPos.y, accuracy: 0.001)
        XCTAssertEqual(position.z, initialPos.z, accuracy: 0.001)
        
        XCTAssertEqual(velocity.x, 0, accuracy: 0.001)
        XCTAssertEqual(velocity.y, 0, accuracy: 0.001)
        XCTAssertEqual(velocity.z, 0, accuracy: 0.001)
    }
    
    func testInitializationWithCustomNoise() {
        let initialPos = simd_float3(0, 0, 0)
        let processNoise: Float = 0.2
        let measurementNoise: Float = 0.8
        
        let filter = SimpleKalmanFilter(initialPosition: initialPos, 
                                       processNoise: processNoise,
                                       measurementNoise: measurementNoise)
        
        // Should initialize without error
        XCTAssertNotNil(filter)
        
        let position = filter.getPosition()
        XCTAssertEqual(position, initialPos)
    }
    
    // MARK: - Prediction Tests
    
    func testPredictionWithoutMovement() {
        let currentTime: TimeInterval = 1.0
        
        // Predict without any previous updates
        let predictedPosition = kalmanFilter.predict(at: currentTime)
        let initialPosition = kalmanFilter.getPosition()
        
        // Without velocity, position should remain the same
        XCTAssertEqual(predictedPosition.x, initialPosition.x, accuracy: 0.001)
        XCTAssertEqual(predictedPosition.y, initialPosition.y, accuracy: 0.001)
        XCTAssertEqual(predictedPosition.z, initialPosition.z, accuracy: 0.001)
    }
    
    func testPredictionWithVelocity() {
        let currentTime: TimeInterval = 0.0
        let futureTime: TimeInterval = 1.0
        
        // First update to establish velocity
        let position1 = simd_float3(0, 0, 0)
        kalmanFilter.update(with: position1, at: currentTime)
        
        // Second update to create velocity
        let position2 = simd_float3(1, 0, 0) // Moved 1 unit in X
        kalmanFilter.update(with: position2, at: currentTime + 1.0)
        
        // Predict one second into future
        let predictedPosition = kalmanFilter.predict(at: futureTime + 1.0)
        
        // Should predict continued motion in X direction
        XCTAssertGreaterThan(predictedPosition.x, position2.x)
    }
    
    // MARK: - Update Tests
    
    func testSingleUpdate() {
        let measurement = simd_float3(5, 10, 15)
        let timestamp: TimeInterval = 1.0
        
        kalmanFilter.update(with: measurement, at: timestamp)
        
        let position = kalmanFilter.getPosition()
        
        // Position should move toward measurement
        XCTAssertGreaterThan(position.x, 0)
        XCTAssertGreaterThan(position.y, 0)
        XCTAssertGreaterThan(position.z, 0)
        
        // Should be close to measurement due to high confidence
        XCTAssertLessThan(abs(position.x - measurement.x), 2.0)
        XCTAssertLessThan(abs(position.y - measurement.y), 2.0)
        XCTAssertLessThan(abs(position.z - measurement.z), 2.0)
    }
    
    func testUpdateWithConfidence() {
        let measurement = simd_float3(10, 0, 0)
        let timestamp: TimeInterval = 1.0
        
        // High confidence update
        kalmanFilter.update(with: measurement, at: timestamp, confidence: 1.0)
        let highConfidencePosition = kalmanFilter.getPosition()
        
        // Reset and test low confidence
        kalmanFilter.reset(to: simd_float3(0, 0, 0))
        kalmanFilter.update(with: measurement, at: timestamp, confidence: 0.1)
        let lowConfidencePosition = kalmanFilter.getPosition()
        
        // High confidence should move closer to measurement
        XCTAssertGreaterThan(highConfidencePosition.x, lowConfidencePosition.x)
    }
    
    func testSequentialUpdates() {
        let baseTime: TimeInterval = 0.0
        let deltaTime: TimeInterval = 0.1
        
        // Create a sequence of measurements showing movement
        let measurements = [
            simd_float3(0, 0, 0),
            simd_float3(1, 0, 0),
            simd_float3(2, 0, 0),
            simd_float3(3, 0, 0)
        ]
        
        for (i, measurement) in measurements.enumerated() {
            kalmanFilter.update(with: measurement, at: baseTime + Double(i) * deltaTime)
        }
        
        let finalVelocity = kalmanFilter.getVelocity()
        
        // Should have learned positive X velocity
        XCTAssertGreaterThan(finalVelocity.x, 0)
        XCTAssertLessThan(abs(finalVelocity.y), 2.0) // Y velocity should be near zero
        XCTAssertLessThan(abs(finalVelocity.z), 2.0) // Z velocity should be near zero
    }
    
    // MARK: - Uncertainty Tests
    
    func testUncertaintyReduction() {
        let initialUncertainty = kalmanFilter.getPositionUncertainty()
        
        // Single measurement should reduce uncertainty
        kalmanFilter.update(with: simd_float3(1, 1, 1), at: 1.0)
        
        let updatedUncertainty = kalmanFilter.getPositionUncertainty()
        
        XCTAssertLessThan(updatedUncertainty.x, initialUncertainty.x)
        XCTAssertLessThan(updatedUncertainty.y, initialUncertainty.y)
        XCTAssertLessThan(updatedUncertainty.z, initialUncertainty.z)
    }
    
    // MARK: - Confidence Tests
    
    func testTrackingConfidence() {
        let initialConfidence = kalmanFilter.getTrackingConfidence()
        
        // Multiple accurate measurements should improve confidence
        for i in 0..<5 {
            kalmanFilter.update(with: simd_float3(Float(i), 0, 0), 
                              at: TimeInterval(i))
        }
        
        let improvedConfidence = kalmanFilter.getTrackingConfidence()
        
        XCTAssertGreaterThan(improvedConfidence, initialConfidence)
        XCTAssertGreaterThan(improvedConfidence, 0.0)
        XCTAssertLessThanOrEqual(improvedConfidence, 1.0)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Establish some state
        kalmanFilter.update(with: simd_float3(10, 20, 30), at: 1.0)
        kalmanFilter.update(with: simd_float3(15, 25, 35), at: 2.0)
        
        let preResetVelocity = kalmanFilter.getVelocity()
        XCTAssertNotEqual(preResetVelocity, simd_float3(0, 0, 0))
        
        // Reset to new position
        let newPosition = simd_float3(100, 200, 300)
        kalmanFilter.reset(to: newPosition)
        
        let postResetPosition = kalmanFilter.getPosition()
        let postResetVelocity = kalmanFilter.getVelocity()
        
        XCTAssertEqual(postResetPosition, newPosition)
        XCTAssertEqual(postResetVelocity.x, 0, accuracy: 0.001)
        XCTAssertEqual(postResetVelocity.y, 0, accuracy: 0.001)
        XCTAssertEqual(postResetVelocity.z, 0, accuracy: 0.001)
    }
    
    // MARK: - Ball Tracker Factory Test
    
    func testBallTrackerFactory() {
        let initialPos = simd_float3(5, 10, 15)
        let ballTracker = SimpleKalmanFilter.ballTracker(initialPosition: initialPos)
        
        XCTAssertEqual(ballTracker.getPosition(), initialPos)
        XCTAssertEqual(ballTracker.getVelocity(), simd_float3(0, 0, 0))
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        let measurement = simd_float3(1, 2, 3)
        let baseTime: TimeInterval = 0.0
        
        let startTime = Date()
        for i in 0..<1000 {
            kalmanFilter.update(with: measurement, at: baseTime + Double(i) * 0.001)
            _ = kalmanFilter.predict(at: baseTime + Double(i) * 0.001 + 0.01)
        }
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete 1000 iterations in reasonable time
        XCTAssertLessThan(elapsed, 1.0)
    }
}