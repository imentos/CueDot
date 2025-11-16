import XCTest
@testable import CueDot

/// Comprehensive tests for AppConfiguration system
/// Validates all constants, computed properties, and validation methods
class AppConfigurationTests: XCTestCase {
    
    // MARK: - Constant Value Tests
    
    func testDetectionTrackingConstants() {
        // Test that all constants match specification values
        XCTAssertEqual(AppConfiguration.confidenceThreshold, 0.85, accuracy: 0.001)
        XCTAssertEqual(AppConfiguration.jitterThreshold, 0.002, accuracy: 0.000001)
        XCTAssertEqual(AppConfiguration.emaAlpha, 0.5, accuracy: 0.001)
    }
    
    func testVisualOverlayConstants() {
        // Test overlay color components
        let colorComponents = AppConfiguration.overlayColorComponents
        XCTAssertEqual(colorComponents.red, 1.0, accuracy: 0.001, "Red component should be 1.0 for pure red")
        XCTAssertEqual(colorComponents.green, 0.0, accuracy: 0.001, "Green component should be 0.0 for pure red")
        XCTAssertEqual(colorComponents.blue, 0.0, accuracy: 0.001, "Blue component should be 0.0 for pure red")
        XCTAssertEqual(colorComponents.alpha, 0.9, accuracy: 0.001, "Alpha should be 0.9 for slight transparency")
        
        // Test dimension ratios
        XCTAssertEqual(AppConfiguration.dotDiameterRatio, 0.06, accuracy: 0.001)
        XCTAssertEqual(AppConfiguration.crosshairLengthRatio, 0.22, accuracy: 0.001)
    }
    
    func testPhysicalConstants() {
        // Test standard pool ball diameter (57mm)
        XCTAssertEqual(AppConfiguration.standardBallDiameter, 0.057, accuracy: 0.001)
    }
    
    func testPerformanceConstants() {
        // Test frame rate and latency targets
        XCTAssertEqual(AppConfiguration.targetFPS, 60)
        XCTAssertEqual(AppConfiguration.maxLatencyMS, 60)
        XCTAssertEqual(AppConfiguration.idealLatencyMS, 30)
        XCTAssertEqual(AppConfiguration.maxGPUUsagePercent, 15.0, accuracy: 0.1)
    }
    
    func testTimingConstants() {
        // Test timing durations
        XCTAssertEqual(AppConfiguration.relightTriggerDuration, 2.0, accuracy: 0.1)
        XCTAssertEqual(AppConfiguration.realignWarningDuration, 5.0, accuracy: 0.1)
        XCTAssertEqual(AppConfiguration.overlayFadeDuration, 0.3, accuracy: 0.01)
    }
    
    // MARK: - Computed Properties Tests
    
    func testStandardDotDiameter() {
        let expectedDotDiameter = AppConfiguration.standardBallDiameter * AppConfiguration.dotDiameterRatio
        XCTAssertEqual(AppConfiguration.standardDotDiameter, expectedDotDiameter, accuracy: 0.0001)
        
        // Verify actual size (57mm * 0.06 = 3.42mm)
        XCTAssertEqual(AppConfiguration.standardDotDiameter, 0.00342, accuracy: 0.00001)
    }
    
    func testStandardCrosshairLength() {
        let expectedCrosshairLength = AppConfiguration.standardBallDiameter * AppConfiguration.crosshairLengthRatio
        XCTAssertEqual(AppConfiguration.standardCrosshairLength, expectedCrosshairLength, accuracy: 0.0001)
        
        // Verify actual size (57mm * 0.22 = 12.54mm)
        XCTAssertEqual(AppConfiguration.standardCrosshairLength, 0.01254, accuracy: 0.00001)
    }
    
    func testTargetFrameInterval() {
        let expectedInterval = 1.0 / Double(AppConfiguration.targetFPS)
        XCTAssertEqual(AppConfiguration.targetFrameInterval, expectedInterval, accuracy: 0.0001)
        
        // For 60 FPS, interval should be ~0.0167 seconds
        XCTAssertEqual(AppConfiguration.targetFrameInterval, 1.0/60.0, accuracy: 0.0001)
    }
    
    func testIdealLatency() {
        let expectedLatency = Double(AppConfiguration.idealLatencyMS) / 1000.0
        XCTAssertEqual(AppConfiguration.idealLatency, expectedLatency, accuracy: 0.0001)
        XCTAssertEqual(AppConfiguration.idealLatency, 0.03, accuracy: 0.001)
    }
    
    func testMaxLatency() {
        let expectedLatency = Double(AppConfiguration.maxLatencyMS) / 1000.0
        XCTAssertEqual(AppConfiguration.maxLatency, expectedLatency, accuracy: 0.0001)
        XCTAssertEqual(AppConfiguration.maxLatency, 0.06, accuracy: 0.001)
    }
    
    // MARK: - Validation Method Tests
    
    func testIsValidConfidence() {
        // Valid confidence values
        XCTAssertTrue(AppConfiguration.isValidConfidence(0.0))
        XCTAssertTrue(AppConfiguration.isValidConfidence(0.5))
        XCTAssertTrue(AppConfiguration.isValidConfidence(0.85))
        XCTAssertTrue(AppConfiguration.isValidConfidence(1.0))
        
        // Invalid confidence values
        XCTAssertFalse(AppConfiguration.isValidConfidence(-0.1))
        XCTAssertFalse(AppConfiguration.isValidConfidence(1.1))
        XCTAssertFalse(AppConfiguration.isValidConfidence(-1.0))
        XCTAssertFalse(AppConfiguration.isValidConfidence(2.0))
        
        // Edge cases
        XCTAssertTrue(AppConfiguration.isValidConfidence(0.001))
        XCTAssertTrue(AppConfiguration.isValidConfidence(0.999))
    }
    
    func testIsValidDistance() {
        // Valid distances (0.1m to 10m)
        XCTAssertTrue(AppConfiguration.isValidDistance(0.1))
        XCTAssertTrue(AppConfiguration.isValidDistance(1.5))
        XCTAssertTrue(AppConfiguration.isValidDistance(5.0))
        XCTAssertTrue(AppConfiguration.isValidDistance(10.0))
        
        // Invalid distances
        XCTAssertFalse(AppConfiguration.isValidDistance(0.05))
        XCTAssertFalse(AppConfiguration.isValidDistance(15.0))
        XCTAssertFalse(AppConfiguration.isValidDistance(-1.0))
        XCTAssertFalse(AppConfiguration.isValidDistance(0.0))
        
        // Edge cases
        XCTAssertFalse(AppConfiguration.isValidDistance(0.099))
        XCTAssertTrue(AppConfiguration.isValidDistance(0.101))
        XCTAssertFalse(AppConfiguration.isValidDistance(10.001))
    }
    
    func testIsValidBallDiameter() {
        // Valid ball diameters (40mm to 80mm)
        XCTAssertTrue(AppConfiguration.isValidBallDiameter(0.040)) // 40mm
        XCTAssertTrue(AppConfiguration.isValidBallDiameter(0.057)) // Standard 57mm
        XCTAssertTrue(AppConfiguration.isValidBallDiameter(0.080)) // 80mm
        XCTAssertTrue(AppConfiguration.isValidBallDiameter(0.060)) // Common size
        
        // Invalid ball diameters
        XCTAssertFalse(AppConfiguration.isValidBallDiameter(0.035)) // Too small
        XCTAssertFalse(AppConfiguration.isValidBallDiameter(0.085)) // Too large
        XCTAssertFalse(AppConfiguration.isValidBallDiameter(0.0))   // Zero
        XCTAssertFalse(AppConfiguration.isValidBallDiameter(-0.05)) // Negative
        
        // Edge cases
        XCTAssertFalse(AppConfiguration.isValidBallDiameter(0.0399))
        XCTAssertTrue(AppConfiguration.isValidBallDiameter(0.0401))
    }
    
    func testIsValidFrameRate() {
        // Valid frame rates (15 to 120 fps)
        XCTAssertTrue(AppConfiguration.isValidFrameRate(15))
        XCTAssertTrue(AppConfiguration.isValidFrameRate(30))
        XCTAssertTrue(AppConfiguration.isValidFrameRate(60))
        XCTAssertTrue(AppConfiguration.isValidFrameRate(120))
        
        // Invalid frame rates
        XCTAssertFalse(AppConfiguration.isValidFrameRate(10))
        XCTAssertFalse(AppConfiguration.isValidFrameRate(150))
        XCTAssertFalse(AppConfiguration.isValidFrameRate(0))
        XCTAssertFalse(AppConfiguration.isValidFrameRate(-30))
        
        // Edge cases
        XCTAssertFalse(AppConfiguration.isValidFrameRate(14))
        XCTAssertTrue(AppConfiguration.isValidFrameRate(16))
        XCTAssertFalse(AppConfiguration.isValidFrameRate(121))
    }
    
    func testIsValidLatency() {
        // Valid latency values (0 to 100ms)
        XCTAssertTrue(AppConfiguration.isValidLatency(0))
        XCTAssertTrue(AppConfiguration.isValidLatency(30))
        XCTAssertTrue(AppConfiguration.isValidLatency(60))
        XCTAssertTrue(AppConfiguration.isValidLatency(100))
        
        // Invalid latency values
        XCTAssertFalse(AppConfiguration.isValidLatency(101))
        XCTAssertFalse(AppConfiguration.isValidLatency(200))
        XCTAssertFalse(AppConfiguration.isValidLatency(-10))
        
        // Edge cases
        XCTAssertTrue(AppConfiguration.isValidLatency(99))
        XCTAssertFalse(AppConfiguration.isValidLatency(101))
    }
    
    func testIsValidGPUUsage() {
        // Valid GPU usage (0% to 50%)
        XCTAssertTrue(AppConfiguration.isValidGPUUsage(0.0))
        XCTAssertTrue(AppConfiguration.isValidGPUUsage(15.0))
        XCTAssertTrue(AppConfiguration.isValidGPUUsage(25.0))
        XCTAssertTrue(AppConfiguration.isValidGPUUsage(50.0))
        
        // Invalid GPU usage
        XCTAssertFalse(AppConfiguration.isValidGPUUsage(-5.0))
        XCTAssertFalse(AppConfiguration.isValidGPUUsage(60.0))
        XCTAssertFalse(AppConfiguration.isValidGPUUsage(100.0))
        
        // Edge cases
        XCTAssertTrue(AppConfiguration.isValidGPUUsage(49.9))
        XCTAssertFalse(AppConfiguration.isValidGPUUsage(50.1))
    }
    
    // MARK: - Configuration Scaling Tests
    
    func testCalculateDotDiameter() {
        // Test with standard ball diameter
        let standardResult = AppConfiguration.calculateDotDiameter(for: 0.057)
        XCTAssertEqual(standardResult, AppConfiguration.standardDotDiameter, accuracy: 0.00001)
        
        // Test with different valid ball sizes
        let smallBall = AppConfiguration.calculateDotDiameter(for: 0.040)
        XCTAssertEqual(smallBall, 0.040 * 0.06, accuracy: 0.00001)
        
        let largeBall = AppConfiguration.calculateDotDiameter(for: 0.080)
        XCTAssertEqual(largeBall, 0.080 * 0.06, accuracy: 0.00001)
        
        // Test with invalid ball diameter - should return standard
        let invalidResult = AppConfiguration.calculateDotDiameter(for: 0.030)
        XCTAssertEqual(invalidResult, AppConfiguration.standardDotDiameter, accuracy: 0.00001)
    }
    
    func testCalculateCrosshairLength() {
        // Test with standard ball diameter
        let standardResult = AppConfiguration.calculateCrosshairLength(for: 0.057)
        XCTAssertEqual(standardResult, AppConfiguration.standardCrosshairLength, accuracy: 0.00001)
        
        // Test with different valid ball sizes
        let smallBall = AppConfiguration.calculateCrosshairLength(for: 0.040)
        XCTAssertEqual(smallBall, 0.040 * 0.22, accuracy: 0.00001)
        
        let largeBall = AppConfiguration.calculateCrosshairLength(for: 0.080)
        XCTAssertEqual(largeBall, 0.080 * 0.22, accuracy: 0.00001)
        
        // Test with invalid ball diameter - should return standard
        let invalidResult = AppConfiguration.calculateCrosshairLength(for: 0.100)
        XCTAssertEqual(invalidResult, AppConfiguration.standardCrosshairLength, accuracy: 0.00001)
    }
    
    func testCalculateScaleFactor() {
        // Test at reference distance (1.5m) - should be 1.0
        let referenceScale = AppConfiguration.calculateScaleFactor(for: 1.5)
        XCTAssertEqual(referenceScale, 1.0, accuracy: 0.001)
        
        // Test at closer distance - should be larger scale
        let closeScale = AppConfiguration.calculateScaleFactor(for: 0.75)
        XCTAssertEqual(closeScale, 2.0, accuracy: 0.001) // 1.5 / 0.75 = 2.0
        
        // Test at farther distance - should be smaller scale
        let farScale = AppConfiguration.calculateScaleFactor(for: 3.0)
        XCTAssertEqual(farScale, 0.5, accuracy: 0.001) // 1.5 / 3.0 = 0.5
        
        // Test with invalid distance - should return 1.0
        let invalidScale = AppConfiguration.calculateScaleFactor(for: 15.0)
        XCTAssertEqual(invalidScale, 1.0, accuracy: 0.001)
        
        // Test edge cases
        let minDistance = AppConfiguration.calculateScaleFactor(for: 0.1)
        XCTAssertEqual(minDistance, 15.0, accuracy: 0.1) // 1.5 / 0.1 = 15.0
    }
    
    // MARK: - Configuration Description Tests
    
    func testConfigurationDescription() {
        let description = AppConfiguration.description
        
        // Verify description contains key values
        XCTAssertTrue(description.contains("0.85"), "Should contain confidence threshold")
        XCTAssertTrue(description.contains("0.002"), "Should contain jitter threshold") 
        XCTAssertTrue(description.contains("0.5"), "Should contain EMA alpha")
        XCTAssertTrue(description.contains("0.06"), "Should contain dot diameter ratio")
        XCTAssertTrue(description.contains("0.22"), "Should contain crosshair length ratio")
        XCTAssertTrue(description.contains("0.057"), "Should contain standard ball diameter")
        XCTAssertTrue(description.contains("60"), "Should contain target FPS")
        XCTAssertTrue(description.contains("30"), "Should contain ideal latency")
        XCTAssertTrue(description.contains("15.0"), "Should contain max GPU usage")
        
        // Verify structure
        XCTAssertTrue(description.contains("Detection & Tracking:"))
        XCTAssertTrue(description.contains("Visual Overlay:"))
        XCTAssertTrue(description.contains("Physical Constants:"))
        XCTAssertTrue(description.contains("Performance Targets:"))
        XCTAssertTrue(description.contains("Timing:"))
        
        // Ensure it's not empty
        XCTAssertGreaterThan(description.count, 100)
    }
    
    // MARK: - Platform Integration Tests
    
    #if canImport(UIKit)
    func testUIColorIntegration() {
        // Test UIColor creation from color components
        let color = AppConfiguration.overlayColor
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        XCTAssertEqual(Float(red), AppConfiguration.overlayColorComponents.red, accuracy: 0.001)
        XCTAssertEqual(Float(green), AppConfiguration.overlayColorComponents.green, accuracy: 0.001)
        XCTAssertEqual(Float(blue), AppConfiguration.overlayColorComponents.blue, accuracy: 0.001)
        XCTAssertEqual(Float(alpha), AppConfiguration.overlayColorComponents.alpha, accuracy: 0.001)
    }
    #endif
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        // Test that validation methods are fast enough for real-time use
        measure {
            for _ in 0..<10000 {
                _ = AppConfiguration.isValidConfidence(0.85)
                _ = AppConfiguration.isValidDistance(1.5)
                _ = AppConfiguration.isValidBallDiameter(0.057)
                _ = AppConfiguration.isValidFrameRate(60)
                _ = AppConfiguration.isValidLatency(30)
                _ = AppConfiguration.isValidGPUUsage(15.0)
            }
        }
    }
    
    func testScalingCalculationPerformance() {
        // Test that scaling calculations are fast enough for real-time use
        measure {
            for _ in 0..<10000 {
                _ = AppConfiguration.calculateDotDiameter(for: 0.057)
                _ = AppConfiguration.calculateCrosshairLength(for: 0.057)
                _ = AppConfiguration.calculateScaleFactor(for: 1.5)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testConfigurationIntegrity() {
        // Verify all configuration values are reasonable and internally consistent
        
        // Confidence threshold should be achievable
        XCTAssertGreaterThanOrEqual(AppConfiguration.confidenceThreshold, 0.5)
        XCTAssertLessThanOrEqual(AppConfiguration.confidenceThreshold, 1.0)
        
        // Jitter threshold should be small but meaningful
        XCTAssertGreaterThan(AppConfiguration.jitterThreshold, 0.0001) // 0.1mm
        XCTAssertLessThan(AppConfiguration.jitterThreshold, 0.01)      // 10mm
        
        // EMA alpha should provide meaningful filtering
        XCTAssertGreaterThan(AppConfiguration.emaAlpha, 0.1)
        XCTAssertLessThan(AppConfiguration.emaAlpha, 0.9)
        
        // Overlay ratios should be reasonable
        XCTAssertGreaterThan(AppConfiguration.dotDiameterRatio, 0.02)  // 2%
        XCTAssertLessThan(AppConfiguration.dotDiameterRatio, 0.2)      // 20%
        
        XCTAssertGreaterThan(AppConfiguration.crosshairLengthRatio, 0.1) // 10%
        XCTAssertLessThan(AppConfiguration.crosshairLengthRatio, 0.5)    // 50%
        
        // Performance targets should be achievable
        XCTAssertGreaterThanOrEqual(AppConfiguration.targetFPS, 30)
        XCTAssertLessThanOrEqual(AppConfiguration.targetFPS, 120)
        
        XCTAssertLessThanOrEqual(AppConfiguration.idealLatencyMS, AppConfiguration.maxLatencyMS)
        
        // Timing should be reasonable
        XCTAssertLessThan(AppConfiguration.relightTriggerDuration, AppConfiguration.realignWarningDuration)
    }
}