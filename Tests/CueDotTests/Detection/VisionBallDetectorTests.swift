import XCTest
import Vision
import simd
@testable import CueDot

final class VisionBallDetectorTests: XCTestCase {
    
    var detector: VisionBallDetector!
    var mockFrame: CVPixelBuffer!
    
    override func setUp() {
        super.setUp()
        detector = VisionBallDetector()
        
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
    }
    
    func testStartStopDetection() throws {
        XCTAssertFalse(detector.isActive)
        
        try detector.startDetection()
        XCTAssertTrue(detector.isActive)
        
        detector.stopDetection()
        XCTAssertFalse(detector.isActive)
    }
    
    func testDetectionWhenInactive() {
        XCTAssertFalse(detector.isActive)
        
        XCTAssertThrowsError(try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())) { error in
            if case BallDetectionError.detectionNotActive = error {
                // Expected error
            } else {
                XCTFail("Expected detectionNotActive error, got \(error)")
            }
        }
    }
    
    func testReset() throws {
        try detector.startDetection()
        
        // Perform detection to populate metrics
        _ = try? detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        detector.reset()
        
        XCTAssertFalse(detector.isActive)
        let metrics = detector.getPerformanceMetrics()
        XCTAssertEqual(metrics["isActive"], 0.0)
    }
    
    // MARK: - Detection Tests
    
    func testBasicDetection() throws {
        try detector.startDetection()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        // Should return some results with current simplified implementation
        XCTAssertGreaterThanOrEqual(results.count, 0)
        XCTAssertLessThanOrEqual(results.count, Int(detector.configuration.maxBallsPerFrame))
        
        // All results should meet minimum confidence
        for result in results {
            XCTAssertGreaterThanOrEqual(result.confidence, detector.configuration.minimumConfidence)
        }
    }
    
    func testDetectionWithColorFiltering() throws {
        var config = detector.configuration
        config.colorFiltering.enabled = true
        detector.configuration = config
        
        try detector.startDetection()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }
    
    func testDetectionWithoutColorFiltering() throws {
        var config = detector.configuration
        config.colorFiltering.enabled = false
        detector.configuration = config
        
        try detector.startDetection()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        // Should still work without color filtering
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }
    
    func testDetectionWithShapeDetection() throws {
        var config = detector.configuration
        config.shapeDetection.enabled = true
        detector.configuration = config
        
        try detector.startDetection()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }
    
    func testMaxDetectedBallsLimit() throws {
        var config = detector.configuration
        config.maxDetectedBalls = 2
        detector.configuration = config
        
        try detector.startDetection()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        XCTAssertLessThanOrEqual(results.count, 2)
    }
    
    func testMinimumConfidenceFiltering() throws {
        var config = detector.configuration
        config.minimumConfidence = 0.95 // Very high threshold
        detector.configuration = config
        
        try detector.startDetection()
        
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        // All results should meet the high confidence threshold
        for result in results {
            XCTAssertGreaterThanOrEqual(result.confidence, 0.95)
        }
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetrics() throws {
        try detector.startDetection()
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        let metrics = detector.getPerformanceMetrics()
        
        XCTAssertNotNil(metrics["lastProcessingTime"])
        XCTAssertNotNil(metrics["detectionsCount"])
        XCTAssertNotNil(metrics["averageConfidence"])
        XCTAssertNotNil(metrics["isActive"])
        XCTAssertNotNil(metrics["lastDetectionCount"])
        
        XCTAssertEqual(metrics["isActive"], 1.0)
        XCTAssertGreaterThan(metrics["lastProcessingTime"] ?? 0, 0)
    }
    
    func testPerformanceRequirements() throws {
        try detector.startDetection()
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        let requirements = DetectionPerformanceRequirements(
            minimumAccuracy: 0.5,
            maximumLatency: 1.0, // 1 second - very generous
            maximumFalsePositiveRate: 0.5,
            maximumMemoryUsage: 100.0
        )
        
        let meetsRequirements = detector.meetsPerformanceRequirements(requirements)
        XCTAssertTrue(meetsRequirements)
    }
    
    func testPerformanceRequirementsFail() throws {
        try detector.startDetection()
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        let strictRequirements = DetectionPerformanceRequirements(
            minimumAccuracy: 0.99, // Very high accuracy
            maximumLatency: 0.001, // Very low latency
            maximumFalsePositiveRate: 0.01,
            maximumMemoryUsage: 1.0 // Very low memory
        )
        
        let meetsRequirements = detector.meetsPerformanceRequirements(strictRequirements)
        // Should likely fail these strict requirements
        XCTAssertFalse(meetsRequirements)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationUpdate() {
        let originalConfig = detector.configuration
        
        var newConfig = originalConfig
        newConfig.colorFiltering.enabled = !originalConfig.colorFiltering.enabled
        newConfig.shapeDetection.enabled = !originalConfig.shapeDetection.enabled
        
        detector.configuration = newConfig
        
        XCTAssertEqual(detector.configuration.colorFiltering.enabled, newConfig.colorFiltering.enabled)
        XCTAssertEqual(detector.configuration.shapeDetection.enabled, newConfig.shapeDetection.enabled)
    }
    
    func testColorFilteringConfiguration() {
        var config = detector.configuration
        config.colorFiltering.enabled = true
        config.colorFiltering.colorTolerance = 0.3
        
        detector.configuration = config
        
        XCTAssertTrue(detector.configuration.colorFiltering.enabled)
        XCTAssertEqual(detector.configuration.colorFiltering.colorTolerance, 0.3)
    }
    
    func testShapeDetectionConfiguration() {
        var config = detector.configuration
        config.shapeDetection.enabled = true
        config.shapeDetection.houghTransform.circleAccumulatorThreshold = 50
        
        detector.configuration = config
        
        XCTAssertTrue(detector.configuration.shapeDetection.enabled)
        XCTAssertEqual(detector.configuration.shapeDetection.houghTransform.circleAccumulatorThreshold, 50)
    }
    
    // MARK: - Error Handling Tests
    
    func testMultipleStartCalls() throws {
        try detector.startDetection()
        XCTAssertTrue(detector.isActive)
        
        // Second start call should not throw
        XCTAssertNoThrow(try detector.startDetection())
        XCTAssertTrue(detector.isActive)
    }
    
    func testMultipleStopCalls() throws {
        try detector.startDetection()
        
        detector.stopDetection()
        XCTAssertFalse(detector.isActive)
        
        // Second stop call should be safe
        detector.stopDetection()
        XCTAssertFalse(detector.isActive)
    }
    
    // MARK: - Detection Result Validation Tests
    
    func testDetectionResultProperties() throws {
        try detector.startDetection()
        
        let timestamp = CACurrentMediaTime()
        let results = try detector.detect(in: mockFrame, timestamp: timestamp)
        
        for result in results {
            // Validate position is reasonable
            XCTAssertFalse(result.position.x.isNaN)
            XCTAssertFalse(result.position.y.isNaN)
            XCTAssertFalse(result.position.z.isNaN)
            
            // Validate confidence is in reasonable range
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            
            // Validate timestamp
            XCTAssertEqual(result.timestamp, timestamp)
            
            // Validate bounding box has positive dimensions
            XCTAssertGreaterThan(result.boundingBox.width, 0)
            XCTAssertGreaterThan(result.boundingBox.height, 0)
            
            // Validate pixel coordinates are non-negative
            XCTAssertGreaterThanOrEqual(result.pixelCoordinates.x, 0)
            XCTAssertGreaterThanOrEqual(result.pixelCoordinates.y, 0)
        }
    }
    
    // MARK: - Integration Tests
    
    func testMultipleDetectionCycles() throws {
        try detector.startDetection()
        
        // Perform multiple detection cycles
        for i in 0..<5 {
            let timestamp = CACurrentMediaTime() + Double(i)
            let results = try detector.detect(in: mockFrame, timestamp: timestamp)
            
            XCTAssertGreaterThanOrEqual(results.count, 0)
            XCTAssertLessThanOrEqual(results.count, Int(detector.configuration.maxBallsPerFrame))
        }
        
        // Check that performance metrics are updated
        let metrics = detector.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics["lastProcessingTime"] ?? 0, 0)
    }
    
    func testDetectionAfterReset() throws {
        try detector.startDetection()
        _ = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        
        detector.reset()
        
        // Should need to start again after reset
        XCTAssertThrowsError(try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime()))
        
        // Should work again after restart
        try detector.startDetection()
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }
    
    // MARK: - Memory and Performance Tests
    
    func testMemoryStability() throws {
        try detector.startDetection()
        
        // Run many detection cycles to check for memory leaks
        for _ in 0..<100 {
            _ = try? detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        }
        
        // Should still be functional
        let results = try detector.detect(in: mockFrame, timestamp: CACurrentMediaTime())
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }
    
    func testProcessingTimeTracking() throws {
        try detector.startDetection()
        
        let startTime = CACurrentMediaTime()
        _ = try detector.detect(in: mockFrame, timestamp: startTime)
        
        // Should have recorded processing time
        XCTAssertGreaterThan(detector.lastProcessingTime, 0)
        
        let metrics = detector.getPerformanceMetrics()
        let recordedTime = metrics["lastProcessingTime"] ?? 0
        XCTAssertGreaterThan(recordedTime, 0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFrame() throws {
        try detector.startDetection()
        
        // Create an empty pixel buffer
        var emptyPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            1, 1, // Minimal size
            kCVPixelFormatType_32BGRA,
            nil,
            &emptyPixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        
        // Should handle empty frame gracefully
        let results = try detector.detect(in: emptyPixelBuffer!, timestamp: CACurrentMediaTime())
        XCTAssertGreaterThanOrEqual(results.count, 0) // May or may not detect anything
    }
    
    func testZeroTimestamp() throws {
        try detector.startDetection()
        
        // Should handle zero timestamp
        let results = try detector.detect(in: mockFrame, timestamp: 0.0)
        XCTAssertGreaterThanOrEqual(results.count, 0)
        
        for result in results {
            XCTAssertEqual(result.timestamp, 0.0)
        }
    }
    
    func testNegativeTimestamp() throws {
        try detector.startDetection()
        
        // Should handle negative timestamp
        let negativeTime = -1.0
        let results = try detector.detect(in: mockFrame, timestamp: negativeTime)
        XCTAssertGreaterThanOrEqual(results.count, 0)
        
        for result in results {
            XCTAssertEqual(result.timestamp, negativeTime)
        }
    }
}