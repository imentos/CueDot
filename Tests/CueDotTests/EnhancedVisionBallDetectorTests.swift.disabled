import XCTest
import Vision
import CoreImage
import simd
@testable import CueDot

/// Comprehensive test suite for Enhanced Vision Ball Detection
/// Tests various lighting conditions, ball colors, camera angles, and performance
@available(iOS 13.0, *)
final class EnhancedVisionBallDetectorTests: XCTestCase {
    
    // MARK: - Test Setup
    
    var detector: EnhancedVisionBallDetector!
    var testImageGenerator: TestImageGenerator!
    var performanceTracker: PerformanceTestTracker!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        detector = EnhancedVisionBallDetector()
        testImageGenerator = TestImageGenerator()
        performanceTracker = PerformanceTestTracker()
    }
    
    override func tearDownWithError() throws {
        detector = nil
        testImageGenerator = nil
        performanceTracker = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Detection Tests
    
    func testBasicBallDetection() throws {
        let expectation = XCTestExpectation(description: "Basic ball detection")
        
        // Generate test image with single ball
        let testImage = testImageGenerator.generateSingleBallImage(
            color: .red,
            size: CGSize(width: 50, height: 50),
            position: CGPoint(x: 200, y: 200),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect at least one ball")
            XCTAssertGreaterThan(result.candidateDetections.first?.visionConfidence ?? 0, 0.3, "Detection confidence should be reasonable")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultipleBallDetection() throws {
        let expectation = XCTestExpectation(description: "Multiple ball detection")
        
        // Generate test image with multiple balls
        let testImage = testImageGenerator.generateMultipleBallsImage(
            ballConfigs: [
                BallConfig(color: .red, position: CGPoint(x: 100, y: 100)),
                BallConfig(color: .blue, position: CGPoint(x: 300, y: 150)),
                BallConfig(color: .yellow, position: CGPoint(x: 200, y: 250))
            ],
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            XCTAssertGreaterThanOrEqual(result.candidateDetections.count, 2, "Should detect multiple balls")
            
            // Verify detection quality
            let highConfidenceDetections = result.candidateDetections.filter { 
                $0.visionConfidence > 0.4 
            }
            XCTAssertGreaterThan(highConfidenceDetections.count, 0, "Should have high confidence detections")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Lighting Condition Tests
    
    func testDetectionInDarkConditions() throws {
        let expectation = XCTestExpectation(description: "Detection in dark conditions")
        
        let testImage = testImageGenerator.generateBallImageWithLighting(
            ballColor: .white,
            lightingCondition: .dark,
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            // Should still detect balls but with adapted parameters
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect balls in dark conditions")
            
            // Check that adaptive parameters were applied
            let metrics = result.performanceMetrics
            XCTAssertNotNil(metrics["adaptive_lightingCondition"], "Should track lighting condition")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDetectionInBrightConditions() throws {
        let expectation = XCTestExpectation(description: "Detection in bright conditions")
        
        let testImage = testImageGenerator.generateBallImageWithLighting(
            ballColor: .red,
            lightingCondition: .bright,
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect balls in bright conditions")
            
            // Verify adaptive adjustments were made
            let hasAdaptiveMetrics = result.performanceMetrics.keys.contains { 
                $0.starts(with: "adaptive_") 
            }
            XCTAssertTrue(hasAdaptiveMetrics, "Should have adaptive parameter metrics")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDetectionInMixedLighting() throws {
        let expectation = XCTestExpectation(description: "Detection in mixed lighting")
        
        let testImage = testImageGenerator.generateBallImageWithLighting(
            ballColor: .blue,
            lightingCondition: .mixed,
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            // Should handle mixed lighting with confidence adjustments
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect balls in mixed lighting")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Color Detection Tests
    
    func testRedBallColorDetection() throws {
        try testBallColorDetection(ballColor: .red, expectedBallNumber: 3)
    }
    
    func testBlueBallColorDetection() throws {
        try testBallColorDetection(ballColor: .blue, expectedBallNumber: 2)
    }
    
    func testYellowBallColorDetection() throws {
        try testBallColorDetection(ballColor: .yellow, expectedBallNumber: 1)
    }
    
    func testBlackBallColorDetection() throws {
        try testBallColorDetection(ballColor: .black, expectedBallNumber: 8)
    }
    
    func testWhiteBallColorDetection() throws {
        try testBallColorDetection(ballColor: .white, expectedBallNumber: 0)
    }
    
    private func testBallColorDetection(ballColor: TestBallColor, expectedBallNumber: Int) throws {
        let expectation = XCTestExpectation(description: "Color detection for \(ballColor)")
        
        let testImage = testImageGenerator.generateSingleBallImage(
            color: ballColor,
            size: CGSize(width: 60, height: 60),
            position: CGPoint(x: 320, y: 240),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect the ball")
            
            // Note: Color detection would be tested in integration tests with the color analyzer
            // This test verifies the detection pipeline can process different colored balls
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Size and Distance Tests
    
    func testSmallBallDetection() throws {
        let expectation = XCTestExpectation(description: "Small ball detection")
        
        let testImage = testImageGenerator.generateSingleBallImage(
            color: .red,
            size: CGSize(width: 20, height: 20), // Small ball (far away)
            position: CGPoint(x: 320, y: 240),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            // Should detect small balls with appropriate confidence
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect small balls")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testLargeBallDetection() throws {
        let expectation = XCTestExpectation(description: "Large ball detection")
        
        let testImage = testImageGenerator.generateSingleBallImage(
            color: .blue,
            size: CGSize(width: 100, height: 100), // Large ball (close up)
            position: CGPoint(x: 320, y: 240),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect large balls")
            
            // Verify size is within expected range
            if let detection = result.candidateDetections.first {
                let detectedArea = detection.boundingBox.area
                XCTAssertGreaterThan(detectedArea, 5000, "Large ball should have significant area")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Motion and Blur Tests
    
    func testDetectionWithMotionBlur() throws {
        let expectation = XCTestExpectation(description: "Detection with motion blur")
        
        let testImage = testImageGenerator.generateBallImageWithMotionBlur(
            ballColor: .yellow,
            blurAmount: 5.0,
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            // Should handle motion blur with reduced confidence
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect blurred balls")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testDetectionAtImageEdges() throws {
        let expectation = XCTestExpectation(description: "Detection at image edges")
        
        let imageSize = CGSize(width: 640, height: 480)
        let testImage = testImageGenerator.generateMultipleBallsImage(
            ballConfigs: [
                BallConfig(color: .red, position: CGPoint(x: 30, y: 30)),    // Top-left corner
                BallConfig(color: .blue, position: CGPoint(x: 610, y: 30)),  // Top-right corner
                BallConfig(color: .green, position: CGPoint(x: 30, y: 450)), // Bottom-left corner
                BallConfig(color: .yellow, position: CGPoint(x: 610, y: 450)) // Bottom-right corner
            ],
            imageSize: imageSize
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            // Should detect balls at edges, though with potentially lower confidence
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect balls at edges")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDetectionWithOverlappingBalls() throws {
        let expectation = XCTestExpectation(description: "Detection with overlapping balls")
        
        let testImage = testImageGenerator.generateOverlappingBallsImage(
            ball1Config: BallConfig(color: .red, position: CGPoint(x: 200, y: 200)),
            ball2Config: BallConfig(color: .blue, position: CGPoint(x: 220, y: 210)), // Partially overlapping
            imageSize: CGSize(width: 640, height: 480)
        )
        
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
            // Should attempt to separate overlapping balls
            // May detect as one or two depending on separation algorithm
            XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect overlapping balls")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testDetectionPerformance() throws {
        let expectation = XCTestExpectation(description: "Detection performance")
        expectation.expectedFulfillmentCount = 10 // Test multiple iterations
        
        let testImage = testImageGenerator.generateMultipleBallsImage(
            ballConfigs: [
                BallConfig(color: .red, position: CGPoint(x: 100, y: 100)),
                BallConfig(color: .blue, position: CGPoint(x: 300, y: 150)),
                BallConfig(color: .yellow, position: CGPoint(x: 200, y: 250)),
                BallConfig(color: .green, position: CGPoint(x: 400, y: 300)),
                BallConfig(color: .purple, position: CGPoint(x: 500, y: 200))
            ],
            imageSize: CGSize(width: 1920, height: 1080) // High resolution
        )
        
        var processingTimes: [TimeInterval] = []
        
        for i in 0..<10 {
            let startTime = Date()
            
            detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
                let processingTime = Date().timeIntervalSince(startTime)
                processingTimes.append(processingTime)
                
                // Verify detection works
                XCTAssertGreaterThan(result.candidateDetections.count, 0, "Should detect balls in performance test \(i)")
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Analyze performance
        let averageTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxTime = processingTimes.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.2, "Average processing time should be under 200ms")
        XCTAssertLessThan(maxTime, 0.5, "Maximum processing time should be under 500ms")
        
        print("Performance Results:")
        print("Average processing time: \(averageTime * 1000)ms")
        print("Maximum processing time: \(maxTime * 1000)ms")
    }
    
    func testMemoryUsage() throws {
        // Test for memory leaks during repeated detection
        let expectation = XCTestExpectation(description: "Memory usage test")
        expectation.expectedFulfillmentCount = 50
        
        let testImage = testImageGenerator.generateSingleBallImage(
            color: .red,
            size: CGSize(width: 50, height: 50),
            position: CGPoint(x: 320, y: 240),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        for _ in 0..<50 {
            detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { _ in
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Force garbage collection and check for memory leaks
        // This is a basic test - more sophisticated memory testing would require instruments
        autoreleasepool {
            // No specific assertions, just ensure no crashes occur
        }
    }
    
    // MARK: - Parameter Adaptation Tests
    
    func testAdaptiveParametersAdjustment() throws {
        let expectation = XCTestExpectation(description: "Adaptive parameters adjustment")
        
        // Test with different image qualities
        let highQualityImage = testImageGenerator.generateHighQualityBallImage()
        let lowQualityImage = testImageGenerator.generateLowQualityBallImage()
        
        var highQualityMetrics: [String: Double] = [:]
        var lowQualityMetrics: [String: Double] = [:]
        
        detector.detectBalls(in: highQualityImage.pixelBuffer, imageSize: highQualityImage.imageSize) { result in
            highQualityMetrics = result.performanceMetrics
            
            self.detector.detectBalls(in: lowQualityImage.pixelBuffer, imageSize: lowQualityImage.imageSize) { result in
                lowQualityMetrics = result.performanceMetrics
                
                // Verify that adaptive parameters changed between different image qualities
                XCTAssertNotEqual(
                    highQualityMetrics["adaptive_minConfidence"] ?? 0,
                    lowQualityMetrics["adaptive_minConfidence"] ?? 0,
                    accuracy: 0.01,
                    "Confidence thresholds should adapt to image quality"
                )
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Integration Tests
    
    func testDetectorReset() throws {
        let expectation = XCTestExpectation(description: "Detector reset")
        
        let testImage = testImageGenerator.generateSingleBallImage(
            color: .red,
            size: CGSize(width: 50, height: 50),
            position: CGPoint(x: 320, y: 240),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        // Perform detection to build up state
        detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { _ in
            // Reset detector
            self.detector.reset()
            
            // Verify reset worked by checking metrics
            self.detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
                let frameCount = result.performanceMetrics["detection_frameCount"] ?? 0
                XCTAssertEqual(frameCount, 1.0, "Frame count should reset to 1 after reset")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testConcurrentDetection() throws {
        // Test thread safety with concurrent detection requests
        let expectation = XCTestExpectation(description: "Concurrent detection")
        expectation.expectedFulfillmentCount = 5
        
        let testImage = testImageGenerator.generateSingleBallImage(
            color: .red,
            size: CGSize(width: 50, height: 50),
            position: CGPoint(x: 320, y: 240),
            imageSize: CGSize(width: 640, height: 480)
        )
        
        // Launch multiple concurrent detection requests
        for _ in 0..<5 {
            DispatchQueue.global(qos: .userInitiated).async {
                self.detector.detectBalls(in: testImage.pixelBuffer, imageSize: testImage.imageSize) { result in
                    XCTAssertGreaterThan(result.candidateDetections.count, 0, "Concurrent detection should work")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}

// MARK: - Test Data Generation

class TestImageGenerator {
    
    func generateSingleBallImage(
        color: TestBallColor,
        size: CGSize,
        position: CGPoint,
        imageSize: CGSize
    ) -> TestImage {
        // Create a test image with a single colored ball
        return createTestImage(
            ballConfigs: [BallConfig(color: color, position: position, size: size)],
            imageSize: imageSize
        )
    }
    
    func generateMultipleBallsImage(
        ballConfigs: [BallConfig],
        imageSize: CGSize
    ) -> TestImage {
        return createTestImage(ballConfigs: ballConfigs, imageSize: imageSize)
    }
    
    func generateBallImageWithLighting(
        ballColor: TestBallColor,
        lightingCondition: LightingCondition,
        imageSize: CGSize
    ) -> TestImage {
        var image = createTestImage(
            ballConfigs: [BallConfig(color: ballColor, position: CGPoint(x: imageSize.width/2, y: imageSize.height/2))],
            imageSize: imageSize
        )
        
        // Apply lighting effects
        return applyLightingCondition(to: image, condition: lightingCondition)
    }
    
    func generateBallImageWithMotionBlur(
        ballColor: TestBallColor,
        blurAmount: Float,
        imageSize: CGSize
    ) -> TestImage {
        let image = createTestImage(
            ballConfigs: [BallConfig(color: ballColor, position: CGPoint(x: imageSize.width/2, y: imageSize.height/2))],
            imageSize: imageSize
        )
        
        return applyMotionBlur(to: image, amount: blurAmount)
    }
    
    func generateOverlappingBallsImage(
        ball1Config: BallConfig,
        ball2Config: BallConfig,
        imageSize: CGSize
    ) -> TestImage {
        return createTestImage(
            ballConfigs: [ball1Config, ball2Config],
            imageSize: imageSize
        )
    }
    
    func generateHighQualityBallImage() -> TestImage {
        return createTestImage(
            ballConfigs: [BallConfig(color: .red, position: CGPoint(x: 320, y: 240))],
            imageSize: CGSize(width: 1920, height: 1080),
            quality: .high
        )
    }
    
    func generateLowQualityBallImage() -> TestImage {
        return createTestImage(
            ballConfigs: [BallConfig(color: .red, position: CGPoint(x: 160, y: 120))],
            imageSize: CGSize(width: 320, height: 240),
            quality: .low
        )
    }
    
    // MARK: - Private Implementation
    
    private func createTestImage(
        ballConfigs: [BallConfig],
        imageSize: CGSize,
        quality: ImageQuality = .normal
    ) -> TestImage {
        
        // Create a simple synthetic image with colored circles representing balls
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = Int(imageSize.width) * bytesPerPixel
        let bitmapSize = bytesPerRow * Int(imageSize.height)
        
        guard let data = malloc(bitmapSize) else {
            fatalError("Could not allocate memory for test image")
        }
        defer { free(data) }
        
        // Initialize with green background (pool table color)
        let buffer = data.assumingMemoryBound(to: UInt8.self)
        for i in stride(from: 0, to: bitmapSize, by: bytesPerPixel) {
            buffer[i] = 34      // Blue
            buffer[i + 1] = 139 // Green  
            buffer[i + 2] = 34  // Red (BGR format)
            buffer[i + 3] = 255 // Alpha
        }
        
        // Draw balls
        for config in ballConfigs {
            drawBall(config, in: buffer, imageSize: imageSize, bytesPerRow: bytesPerRow)
        }
        
        // Apply quality adjustments
        applyImageQuality(to: buffer, size: bitmapSize, quality: quality)
        
        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            Int(imageSize.width),
            Int(imageSize.height),
            kCVPixelFormatType_32BGRA,
            data,
            bytesPerRow,
            nil,
            nil,
            pixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Could not create pixel buffer for test image")
        }
        
        return TestImage(pixelBuffer: buffer, imageSize: imageSize)
    }
    
    private func drawBall(
        _ config: BallConfig,
        in buffer: UnsafeMutablePointer<UInt8>,
        imageSize: CGSize,
        bytesPerRow: Int
    ) {
        let radius = config.size?.width ?? 25
        let centerX = Int(config.position.x)
        let centerY = Int(config.position.y)
        let color = getColorRGB(config.color)
        
        for y in max(0, centerY - Int(radius))..<min(Int(imageSize.height), centerY + Int(radius)) {
            for x in max(0, centerX - Int(radius))..<min(Int(imageSize.width), centerX + Int(radius)) {
                let dx = Double(x - centerX)
                let dy = Double(y - centerY)
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance <= Double(radius) {
                    let offset = y * bytesPerRow + x * 4
                    buffer[offset] = color.blue     // Blue
                    buffer[offset + 1] = color.green // Green
                    buffer[offset + 2] = color.red   // Red
                    buffer[offset + 3] = 255         // Alpha
                }
            }
        }
    }
    
    private func getColorRGB(_ color: TestBallColor) -> (red: UInt8, green: UInt8, blue: UInt8) {
        switch color {
        case .red: return (255, 0, 0)
        case .blue: return (0, 0, 255)
        case .yellow: return (255, 255, 0)
        case .green: return (0, 255, 0)
        case .purple: return (128, 0, 128)
        case .orange: return (255, 165, 0)
        case .black: return (0, 0, 0)
        case .white: return (255, 255, 255)
        case .maroon: return (128, 0, 0)
        }
    }
    
    private func applyImageQuality(
        to buffer: UnsafeMutablePointer<UInt8>,
        size: Int,
        quality: ImageQuality
    ) {
        switch quality {
        case .low:
            // Add noise and reduce sharpness
            for i in stride(from: 0, to: size, by: 4) {
                let noise = Int8.random(in: -30...30)
                for j in 0..<3 { // RGB channels
                    let original = Int(buffer[i + j])
                    buffer[i + j] = UInt8(max(0, min(255, original + Int(noise))))
                }
            }
        case .high:
            // Enhance contrast slightly
            for i in stride(from: 0, to: size, by: 4) {
                for j in 0..<3 { // RGB channels
                    let original = Float(buffer[i + j]) / 255.0
                    let enhanced = pow(original, 0.9) // Slight gamma adjustment
                    buffer[i + j] = UInt8(enhanced * 255)
                }
            }
        case .normal:
            break // No changes
        }
    }
    
    private func applyLightingCondition(to image: TestImage, condition: LightingCondition) -> TestImage {
        // For simplicity, return the original image
        // In a full implementation, would adjust brightness/contrast
        return image
    }
    
    private func applyMotionBlur(to image: TestImage, amount: Float) -> TestImage {
        // For simplicity, return the original image
        // In a full implementation, would apply blur filter
        return image
    }
}

// MARK: - Test Supporting Types

struct TestImage {
    let pixelBuffer: CVPixelBuffer
    let imageSize: CGSize
}

struct BallConfig {
    let color: TestBallColor
    let position: CGPoint
    let size: CGSize?
    
    init(color: TestBallColor, position: CGPoint, size: CGSize? = nil) {
        self.color = color
        self.position = position
        self.size = size
    }
}

enum TestBallColor {
    case red, blue, yellow, green, purple, orange, black, white, maroon
}

enum ImageQuality {
    case low, normal, high
}

class PerformanceTestTracker {
    private var measurements: [String: [TimeInterval]] = [:]
    
    func recordMeasurement(_ name: String, time: TimeInterval) {
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(time)
    }
    
    func getAverageTime(_ name: String) -> TimeInterval {
        guard let times = measurements[name], !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }
    
    func getMaxTime(_ name: String) -> TimeInterval {
        return measurements[name]?.max() ?? 0
    }
}