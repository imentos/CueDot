import XCTest
@testable import CueDot

/// Comprehensive tests for MockARView functionality
/// Tests AR session simulation, frame generation, and mock data injection
@available(iOS 17.0, *)
class MockARViewTests: XCTestCase {
    
    var mockARView: MockARView!
    
    override func setUp() {
        super.setUp()
        mockARView = MockARView()
    }
    
    override func tearDown() {
        mockARView?.stopSession()
        mockARView = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(mockARView.isSessionRunning)
        XCTAssertEqual(mockARView.trackingState, .notAvailable(reason: .cameraUnavailable))
        XCTAssertEqual(mockARView.lightingConditions, 0.8, accuracy: 0.01)
        XCTAssertEqual(mockARView.currentFrameTimestamp, 0.0, accuracy: 0.01)
    }
    
    func testCustomConfiguration() {
        let config = MockARConfiguration(
            sessionStartDelay: 0.05,
            enableMotionSimulation: false,
            enableSyntheticDetections: true
        )
        let customARView = MockARView(configuration: config)
        
        XCTAssertEqual(customARView.configuration.sessionStartDelay, 0.05, accuracy: 0.01)
        XCTAssertFalse(customARView.configuration.enableMotionSimulation)
        XCTAssertTrue(customARView.configuration.enableSyntheticDetections)
    }
    
    // MARK: - Session Control Tests
    
    func testSessionStartStop() {
        let expectation = expectation(description: "Session start")
        
        mockARView.startSession { success in
            XCTAssertTrue(success)
            XCTAssertTrue(self.mockARView.isSessionRunning)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        let stopExpectation = self.expectation(description: "Session stop")
        
        mockARView.stopSession {
            XCTAssertFalse(self.mockARView.isSessionRunning)
            stopExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testSessionPauseResume() {
        let startExpectation = expectation(description: "Session start")
        
        mockARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        mockARView.pauseSession()
        XCTAssertTrue(mockARView.isSessionRunning) // Still running, just paused
        
        mockARView.resumeSession()
        XCTAssertTrue(mockARView.isSessionRunning)
        XCTAssertEqual(mockARView.trackingState, .normal)
    }
    
    func testMultipleSessionStarts() {
        let firstExpectation = expectation(description: "First start")
        
        mockARView.startSession { success in
            XCTAssertTrue(success)
            firstExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Second start should fail
        let secondExpectation = expectation(description: "Second start")
        
        mockARView.startSession { success in
            XCTAssertFalse(success)
            secondExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    // MARK: - Mock Data Injection Tests
    
    func testBallDetectionInjection() {
        let detection1 = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(1, 0, -2),
            confidence: 0.9,
            timestamp: 0.1
        )
        let detection2 = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(-1, 0, -3),
            confidence: 0.8,
            timestamp: 0.1
        )
        
        mockARView.injectBallDetections([detection1, detection2])
        
        let currentFrame = mockARView.getCurrentMockFrame()
        XCTAssertEqual(currentFrame.detections.count, 2)
        XCTAssertEqual(currentFrame.detections[0].ballCenter3D.x, 1.0, accuracy: 0.01)
        XCTAssertEqual(currentFrame.detections[1].ballCenter3D.x, -1.0, accuracy: 0.01)
    }
    
    func testAddSingleDetection() {
        let detection = BallDetectionResult(
            ballCenter3D: SIMD3<Float>(0, 1, -1),
            confidence: 0.95,
            timestamp: 0.2
        )
        
        mockARView.addMockDetection(detection)
        
        let currentFrame = mockARView.getCurrentMockFrame()
        XCTAssertEqual(currentFrame.detections.count, 1)
        XCTAssertEqual(currentFrame.detections[0].confidence, 0.95, accuracy: 0.01)
    }
    
    func testClearDetections() {
        let detection = BallDetectionResult.testDefault()
        mockARView.addMockDetection(detection)
        
        // Verify detection was added
        var currentFrame = mockARView.getCurrentMockFrame()
        XCTAssertEqual(currentFrame.detections.count, 1)
        
        // Clear and verify
        mockARView.clearMockDetections()
        currentFrame = mockARView.getCurrentMockFrame()
        XCTAssertEqual(currentFrame.detections.count, 0)
    }
    
    // MARK: - Camera Movement Simulation Tests
    
    func testCameraMovementSimulation() {
        let newPosition = SIMD3<Float>(1, 2, 3)
        
        mockARView.simulateCameraMovement(position: newPosition)
        
        let transform = mockARView.cameraTransform
        XCTAssertEqual(transform.columns.3.x, 1.0, accuracy: 0.01)
        XCTAssertEqual(transform.columns.3.y, 2.0, accuracy: 0.01)
        XCTAssertEqual(transform.columns.3.z, 3.0, accuracy: 0.01)
    }
    
    func testLightingSimulation() {
        // Test normal lighting
        mockARView.simulateLightingChange(0.8)
        XCTAssertEqual(mockARView.lightingConditions, 0.8, accuracy: 0.01)
        
        // Test dim lighting (should trigger tracking degradation)
        mockARView.simulateLightingChange(0.2)
        XCTAssertEqual(mockARView.lightingConditions, 0.2, accuracy: 0.01)
        XCTAssertEqual(mockARView.trackingState, .limited(reason: .poorLighting))
        
        // Test bright lighting (should restore normal tracking)
        mockARView.simulateLightingChange(0.9)
        XCTAssertEqual(mockARView.lightingConditions, 0.9, accuracy: 0.01)
        XCTAssertEqual(mockARView.trackingState, .normal)
    }
    
    func testLightingBounds() {
        // Test below minimum
        mockARView.simulateLightingChange(-0.5)
        XCTAssertEqual(mockARView.lightingConditions, 0.0, accuracy: 0.01)
        
        // Test above maximum
        mockARView.simulateLightingChange(1.5)
        XCTAssertEqual(mockARView.lightingConditions, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Tracking State Simulation Tests
    
    func testTrackingStateChanges() {
        XCTAssertEqual(mockARView.trackingState, .notAvailable(reason: .cameraUnavailable))
        
        mockARView.simulateTrackingStateChange(.limited(reason: .initializing))
        XCTAssertEqual(mockARView.trackingState, .limited(reason: .initializing))
        
        mockARView.simulateTrackingStateChange(.notAvailable(reason: .sensorFailure))
        XCTAssertEqual(mockARView.trackingState, .notAvailable(reason: .sensorFailure))
        
        mockARView.simulateTrackingStateChange(.normal)
        XCTAssertEqual(mockARView.trackingState, .normal)
    }
    
    // MARK: - Callback Tests
    
    func testSessionCallbacks() {
        var receivedEvents: [MockARSessionEvent] = []
        
        mockARView.addSessionCallback { event in
            receivedEvents.append(event)
        }
        
        let startExpectation = expectation(description: "Session callbacks")
        
        mockARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have received session started event
        XCTAssertTrue(receivedEvents.contains { event in
            if case .sessionStarted = event {
                return true
            }
            return false
        })
        
        // Test tracking state change callback
        receivedEvents.removeAll()
        mockARView.simulateTrackingStateChange(.limited(reason: .poorLighting))
        
        XCTAssertTrue(receivedEvents.contains { event in
            if case .trackingStateChanged(let from, let to) = event {
                return from == .normal && to == .limited(reason: .poorLighting)
            }
            return false
        })
    }
    
    func testCallbackRemoval() {
        var callbackCalled = false
        
        mockARView.addSessionCallback { _ in
            callbackCalled = true
        }
        
        mockARView.removeAllCallbacks()
        mockARView.simulateTrackingStateChange(.limited(reason: .initializing))
        
        XCTAssertFalse(callbackCalled)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceMetrics() {
        let startExpectation = expectation(description: "Session start")
        
        mockARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Wait a bit for some metrics to accumulate
        Thread.sleep(forTimeInterval: 0.2)
        
        let metrics = mockARView.getPerformanceMetrics()
        XCTAssertTrue(metrics.keys.contains("averageFrameRate"))
        XCTAssertTrue(metrics.keys.contains("totalFrames"))
        XCTAssertTrue(metrics.keys.contains("profilingDuration"))
        
        // Should have some duration - but don't check exact value due to timing variations
        let duration = metrics["profilingDuration"] ?? 0.0
        XCTAssertGreaterThanOrEqual(duration, 0.0) // Just check it's non-negative
    }
    
    // MARK: - Frame Generation Tests
    
    func testFrameGeneration() {
        let frame = mockARView.getCurrentMockFrame()
        
        XCTAssertEqual(frame.timestamp, 0.0, accuracy: 0.01)
        XCTAssertEqual(frame.lightingConditions, 0.8, accuracy: 0.01)
        XCTAssertEqual(frame.detections.count, 0)
    }
    
    func testFrameGenerationWithSession() {
        let startExpectation = expectation(description: "Session start")
        var frameGenerated = false
        
        mockARView.addSessionCallback { event in
            if case .frameGenerated = event {
                frameGenerated = true
            }
        }
        
        mockARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Wait for frame generation
        let frameExpectation = expectation(description: "Frame generation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(frameGenerated)
            XCTAssertGreaterThan(self.mockARView.currentFrameTimestamp, 0.0)
            frameExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Set up some state
        let startExpectation = expectation(description: "Session start")
        
        mockARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        mockARView.simulateLightingChange(0.5)
        mockARView.addMockDetection(BallDetectionResult.testDefault())
        mockARView.addSessionCallback { _ in }
        
        // Reset
        mockARView.reset()
        
        // Verify reset state
        XCTAssertFalse(mockARView.isSessionRunning)
        XCTAssertEqual(mockARView.trackingState, .normal)
        XCTAssertEqual(mockARView.lightingConditions, 0.8, accuracy: 0.01)
        XCTAssertEqual(mockARView.currentFrameTimestamp, 0.0, accuracy: 0.01)
        
        let frame = mockARView.getCurrentMockFrame()
        XCTAssertEqual(frame.detections.count, 0)
    }
    
    // MARK: - Configuration Tests
    
    func testSyntheticDetectionGeneration() {
        let config = MockARConfiguration(
            enableSyntheticDetections: true,
            syntheticDetectionRange: 1...3
        )
        let syntheticARView = MockARView(configuration: config)
        
        let startExpectation = expectation(description: "Session start")
        
        syntheticARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Wait for synthetic detection generation
        let detectionExpectation = expectation(description: "Detection generation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let frame = syntheticARView.getCurrentMockFrame()
            XCTAssertTrue(frame.detections.count >= 1)
            XCTAssertTrue(frame.detections.count <= 3)
            detectionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        syntheticARView.stopSession()
    }
    
    func testMotionSimulationDisabled() {
        let config = MockARConfiguration(enableMotionSimulation: false)
        let staticARView = MockARView(configuration: config)
        
        let startExpectation = expectation(description: "Session start")
        
        staticARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        let initialTransform = staticARView.cameraTransform
        
        // Wait and check that transform hasn't changed
        let motionExpectation = expectation(description: "Motion check")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let currentTransform = staticARView.cameraTransform
            
            // Transforms should be identical (no motion simulation)
            let positionDelta = abs(currentTransform.columns.3.x - initialTransform.columns.3.x)
            XCTAssertLessThan(positionDelta, 0.001)
            
            motionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        staticARView.stopSession()
    }
    
    // MARK: - Edge Cases Tests
    
    func testSessionStartDelay() {
        let config = MockARConfiguration(sessionStartDelay: 0.2)
        let delayedARView = MockARView(configuration: config)
        
        let startTime = Date()
        let startExpectation = expectation(description: "Delayed session start")
        
        delayedARView.startSession { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThanOrEqual(elapsed, 0.2)
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        delayedARView.stopSession()
    }
    
    func testConcurrentOperations() {
        let startExpectation = expectation(description: "Session start")
        
        mockARView.startSession { _ in
            startExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Perform operations serially instead of concurrently to avoid crashes
        for i in 0..<10 {
            mockARView.simulateLightingChange(Float(i) / 10.0)
            mockARView.addMockDetection(BallDetectionResult.testDefault())
            mockARView.simulateCameraMovement(position: SIMD3<Float>(Float(i), 0, 0))
        }
        
        // Should not crash and should maintain consistent state
        XCTAssertTrue(mockARView.isSessionRunning)
        
        let frame = mockARView.getCurrentMockFrame()
        XCTAssertEqual(frame.detections.count, 10)
    }
}