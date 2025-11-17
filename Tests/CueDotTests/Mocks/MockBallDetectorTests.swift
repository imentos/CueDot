import XCTest
import simd
@testable import CueDot

final class MockBallDetectorTests: XCTestCase {
    
    var detector: MockBallDetector!
    var mockFrame: CVPixelBuffer!
    
    override func setUp() {
        super.setUp()
        detector = MockBallDetector()
        
        // Create a mock CVPixelBuffer for testing
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            640, 480,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        mockFrame = pixelBuffer!
    }
    
    override func tearDown() {
        detector = nil
        mockFrame = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(detector)
        XCTAssertFalse(detector.isActive)
        XCTAssertEqual(detector.lastProcessingTime, 0)
        XCTAssertFalse(detector.mockBallPositions.isEmpty, "Should have default mock data")
    }
    
    func testStartStopDetection() throws {
        XCTAssertFalse(detector.isActive)
        
        try detector.startDetection()
        XCTAssertTrue(detector.isActive)
        
        detector.stopDetection()
        XCTAssertFalse(detector.isActive)
    }
    
    func testReset() throws {
        try detector.startDetection()
        detector.addMockBall(position: simd_float3(1, 2, 3))
        
        detector.reset()
        
        XCTAssertFalse(detector.isActive)
        let metrics = detector.getPerformanceMetrics()
        XCTAssertEqual(metrics.count, 2) // Only default metrics should remain
    }
    
    // MARK: - Detection Tests
    
    func testBasicDetection() throws {
        detector.setMockScenario(.singleBall)
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].color, .white)
        XCTAssertEqual(results[0].ballNumber, 0)
        XCTAssertGreaterThan(results[0].confidence, 0.9)
    }
    
    func testEmptyDetection() throws {
        detector.setMockScenario(.empty)
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertTrue(results.isEmpty)
    }
    
    func testStandardRackDetection() throws {
        detector.setMockScenario(.standardRack)
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertEqual(results.count, 9) // Standard 9-ball rack
        XCTAssertTrue(results.allSatisfy { $0.confidence >= detector.configuration.minimumConfidence })
    }
    
    func testMaxDetectedBallsLimit() throws {
        detector.configuration.maxBallsPerFrame = 3
        detector.setMockScenario(.standardRack)
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertLessThanOrEqual(results.count, 3)
    }
    
    func testConfidenceFiltering() throws {
        detector.configuration.minimumConfidence = 0.95
        detector.setMockScenario(.lowConfidence) // All balls have confidence 0.4
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertTrue(results.isEmpty, "Low confidence balls should be filtered out")
    }
    
    // MARK: - Mock Data Management Tests
    
    func testAddMockBall() {
        let initialCount = detector.mockBallPositions.count
        let position = simd_float3(1, 2, 3)
        
        detector.addMockBall(position: position, confidence: 0.8, color: .red, ballNumber: 5)
        
        XCTAssertEqual(detector.mockBallPositions.count, initialCount + 1)
        XCTAssertEqual(detector.mockBallPositions.last, position)
        XCTAssertEqual(detector.mockConfidenceLevels.last, 0.8)
        XCTAssertEqual(detector.mockBallColors.last, .red)
        XCTAssertEqual(detector.mockBallNumbers.last, 5)
    }
    
    func testClearMockBalls() {
        detector.clearMockBalls()
        
        XCTAssertTrue(detector.mockBallPositions.isEmpty)
        XCTAssertTrue(detector.mockConfidenceLevels.isEmpty)
        XCTAssertTrue(detector.mockBallColors.isEmpty)
        XCTAssertTrue(detector.mockBallNumbers.isEmpty)
    }
    
    func testMoveMockBall() {
        detector.setMockScenario(.singleBall)
        let newPosition = simd_float3(5, 6, 7)
        
        detector.moveMockBall(at: 0, to: newPosition)
        
        XCTAssertEqual(detector.mockBallPositions[0], newPosition)
    }
    
    func testMoveInvalidBallIndex() {
        detector.setMockScenario(.singleBall)
        let originalPosition = detector.mockBallPositions[0]
        
        detector.moveMockBall(at: 999, to: simd_float3(1, 2, 3))
        
        XCTAssertEqual(detector.mockBallPositions[0], originalPosition, "Position should not change for invalid index")
    }
    
    // MARK: - Scenario Tests
    
    func testScenarioEmpty() throws {
        detector.setMockScenario(.empty)
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertTrue(results.isEmpty)
    }
    
    func testScenarioSingleBall() throws {
        detector.setMockScenario(.singleBall)
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertEqual(results.count, 1)
    }
    
    func testScenarioStandardRack() throws {
        detector.setMockScenario(.standardRack)
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertEqual(results.count, 9)
    }
    
    func testScenarioScattered() throws {
        detector.setMockScenario(.scattered)
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertLessThanOrEqual(results.count, 6)
    }
    
    func testScenarioPartialOcclusion() throws {
        detector.configuration.minimumConfidence = 0.5
        detector.setMockScenario(.partialOcclusion)
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertLessThan(results.count, 9) // Some balls should be filtered out
    }
    
    // MARK: - Noise and Failure Simulation Tests
    
    func testPositionalNoise() throws {
        detector.setMockScenario(.singleBall)
        detector.addPositionalNoise = true
        detector.noiseLevel = 0.1
        
        let originalPosition = detector.mockBallPositions[0]
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertEqual(results.count, 1)
        
        // Position should be different due to noise
        let detectedPosition = results[0].position
        let distance = length(detectedPosition - originalPosition)
        XCTAssertGreaterThan(distance, 0, "Position should have noise applied")
        XCTAssertLessThan(distance, 0.2, "Noise should be reasonable")
    }
    
    func testSimulatedFailure() throws {
        detector.setMockScenario(.singleBall)
        detector.simulateFailures = true
        detector.failureProbability = 1.0 // Always fail
        
        XCTAssertThrowsError(try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())) { error in
            XCTAssertTrue(error is BallDetectionError)
        }
    }
    
    func testProcessingDelay() throws {
        detector.setMockScenario(.singleBall)
        detector.simulateProcessingDelay = true
        detector.processingDelay = 0.01 // 10ms
        
        let startTime = CACurrentMediaTime()
        _ = try detector.detect(in: mockFrame, timestamp: startTime)
        let endTime = CACurrentMediaTime()
        
        XCTAssertGreaterThanOrEqual(endTime - startTime, detector.processingDelay)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetrics() throws {
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        let metrics = detector.getPerformanceMetrics()
        
        XCTAssertNotNil(metrics["lastProcessingTime"])
        XCTAssertNotNil(metrics["detectionsCount"])
        XCTAssertNotNil(metrics["averageConfidence"])
        XCTAssertNotNil(metrics["isActive"])
        XCTAssertNotNil(metrics["configuredMaxBalls"])
        XCTAssertNotNil(metrics["mockBallCount"])
    }
    
    func testPerformanceRequirements() throws {
        detector.simulateProcessingDelay = false // Fast processing
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        let requirements = DetectionPerformanceRequirements(
            minimumAccuracy: 0.9,
            maximumLatency: 0.02,
            maximumFalsePositiveRate: 0.1,
            maximumMemoryUsage: 100.0
        )
        
        XCTAssertTrue(detector.meetsPerformanceRequirements(requirements))
    }
    
    func testPerformanceRequirementsFail() throws {
        detector.simulateProcessingDelay = true
        detector.processingDelay = 0.1 // Very slow
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        let strictRequirements = DetectionPerformanceRequirements(
            minimumAccuracy: 0.99,
            maximumLatency: 0.001, // Very fast requirement
            maximumFalsePositiveRate: 0.01,
            maximumMemoryUsage: 10.0
        )
        
        XCTAssertFalse(detector.meetsPerformanceRequirements(strictRequirements))
    }
    
    // MARK: - Factory Tests
    
    func testHighPerformanceFactory() {
        let detector = MockBallDetectorFactory.highPerformance()
        
        XCTAssertFalse(detector.simulateProcessingDelay)
        XCTAssertFalse(detector.addPositionalNoise)
        XCTAssertFalse(detector.simulateFailures)
        XCTAssertTrue(detector.configuration.performance.enableGPUAcceleration)
    }
    
    func testRealisticFactory() {
        let detector = MockBallDetectorFactory.realistic()
        
        XCTAssertTrue(detector.simulateProcessingDelay)
        XCTAssertTrue(detector.addPositionalNoise)
        XCTAssertTrue(detector.simulateFailures)
        XCTAssertGreaterThan(detector.processingDelay, 0)
        XCTAssertGreaterThan(detector.noiseLevel, 0)
        XCTAssertGreaterThan(detector.failureProbability, 0)
    }
    
    func testStressTestingFactory() {
        let detector = MockBallDetectorFactory.stressTesting()
        
        XCTAssertTrue(detector.simulateProcessingDelay)
        XCTAssertTrue(detector.addPositionalNoise)
        XCTAssertTrue(detector.simulateFailures)
        XCTAssertGreaterThan(detector.processingDelay, 0.01) // Slower than realistic
        XCTAssertGreaterThan(detector.noiseLevel, 0.001)    // More noise than realistic
        XCTAssertGreaterThan(detector.failureProbability, 0.05) // More failures than realistic
    }
    
    // MARK: - Edge Cases
    
    func testDetectionWithNoMockData() throws {
        detector.clearMockBalls()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertTrue(results.isEmpty)
    }
    
    func testDetectionWithNegativeConfidence() {
        detector.clearMockBalls()
        detector.addMockBall(position: simd_float3(0, 0, 0), confidence: -0.5)
        
        // Should handle negative confidence gracefully
        XCTAssertNoThrow(try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime()))
    }
    
    func testDetectionWithVeryHighConfidence() throws {
        detector.clearMockBalls()
        detector.addMockBall(position: simd_float3(0, 0, 0), confidence: 2.0) // Above 1.0
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].confidence, 2.0) // Should preserve the value
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationUpdate() {
        let newConfig = BallDetectionConfiguration(
            colorFiltering: PlatformColorFilteringSettings(enabled: false),
            shapeDetection: ShapeDetectionSettings(enabled: false),
            performance: PerformanceSettings(enableGPUAcceleration: false),
            validation: ValidationSettings(enableBoundsChecking: false)
        )
        
        detector.configuration = newConfig
        
        XCTAssertFalse(detector.configuration.colorFiltering.enabled)
        XCTAssertFalse(detector.configuration.shapeDetection.enabled)
        XCTAssertFalse(detector.configuration.performance.enableGPUAcceleration)
        XCTAssertFalse(detector.configuration.validation.enableBoundsChecking)
    }
    
    // MARK: - Bounding Box and Pixel Coordinate Tests
    
    func testBoundingBoxGeneration() throws {
        detector.setMockScenario(.singleBall)
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertEqual(results.count, 1)
        let boundingBox = results[0].boundingBox
        XCTAssertGreaterThan(boundingBox.width, 0)
        XCTAssertGreaterThan(boundingBox.height, 0)
    }
    
    func testPixelCoordinateGeneration() throws {
        detector.setMockScenario(.singleBall)
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertEqual(results.count, 1)
        let pixelCoords = results[0].pixelCoordinates
        XCTAssertGreaterThanOrEqual(pixelCoords.x, 0)
        XCTAssertGreaterThanOrEqual(pixelCoords.y, 0)
    }
}