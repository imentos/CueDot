import XCTest
@testable import CueDot

/// Comprehensive tests for ConfigurationError enum
/// Validates error handling, descriptions, and categorization
class ConfigurationErrorTests: XCTestCase {
    
    // MARK: - Error Creation Tests
    
    func testValidationErrors() {
        // Test confidence validation error
        let confidenceError = ConfigurationError.invalidConfidence(1.5)
        XCTAssertTrue(confidenceError.errorDescription?.contains("1.5") == true)
        XCTAssertTrue(confidenceError.errorDescription?.contains("0.0 and 1.0") == true)
        
        // Test distance validation error
        let distanceError = ConfigurationError.invalidDistance(15.0)
        XCTAssertTrue(distanceError.errorDescription?.contains("15.0") == true)
        XCTAssertTrue(distanceError.errorDescription?.contains("0.1m and 10m") == true)
        
        // Test ball diameter error
        let diameterError = ConfigurationError.invalidBallDiameter(0.100)
        XCTAssertTrue(diameterError.errorDescription?.contains("100") == true) // 100mm
        XCTAssertTrue(diameterError.errorDescription?.contains("40mm and 80mm") == true)
        
        // Test frame rate error
        let fpsError = ConfigurationError.invalidFrameRate(200)
        XCTAssertTrue(fpsError.errorDescription?.contains("200") == true)
        XCTAssertTrue(fpsError.errorDescription?.contains("15 and 120") == true)
        
        // Test latency error
        let latencyError = ConfigurationError.invalidLatency(150)
        XCTAssertTrue(latencyError.errorDescription?.contains("150") == true)
        XCTAssertTrue(latencyError.errorDescription?.contains("100ms") == true)
        
        // Test GPU usage error
        let gpuError = ConfigurationError.invalidGPUUsage(75.0)
        XCTAssertTrue(gpuError.errorDescription?.contains("75") == true)
        XCTAssertTrue(gpuError.errorDescription?.contains("50%") == true)
    }
    
    func testHardwareErrors() {
        // Test unsupported hardware error
        let hardwareError = ConfigurationError.unsupportedHardware
        XCTAssertTrue(hardwareError.errorDescription?.contains("does not support") == true)
        XCTAssertTrue(hardwareError.errorDescription?.contains("AR features") == true)
        
        // Test camera permission error
        let permissionError = ConfigurationError.cameraPermissionDenied
        XCTAssertTrue(permissionError.errorDescription?.contains("Camera permission") == true)
        XCTAssertTrue(permissionError.errorDescription?.contains("required") == true)
        
        // Test sensor unavailable error
        let sensorError = ConfigurationError.sensorUnavailable
        XCTAssertTrue(sensorError.errorDescription?.contains("sensors") == true)
        XCTAssertTrue(sensorError.errorDescription?.contains("not available") == true)
    }
    
    func testConfigurationErrors() {
        // Test invalid parameter combination
        let combinationError = ConfigurationError.invalidParameterCombination("EMA alpha and jitter threshold conflict")
        XCTAssertTrue(combinationError.errorDescription?.contains("Invalid parameter combination") == true)
        XCTAssertTrue(combinationError.errorDescription?.contains("EMA alpha and jitter threshold conflict") == true)
        
        // Test missing required parameter
        let missingError = ConfigurationError.missingRequiredParameter("confidenceThreshold")
        XCTAssertTrue(missingError.errorDescription?.contains("Missing required") == true)
        XCTAssertTrue(missingError.errorDescription?.contains("confidenceThreshold") == true)
        
        // Test exceeds platform limits
        let limitsError = ConfigurationError.exceedsPlatformLimits("Frame rate too high for device")
        XCTAssertTrue(limitsError.errorDescription?.contains("exceeds platform limits") == true)
        XCTAssertTrue(limitsError.errorDescription?.contains("Frame rate too high") == true)
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let errors: [ConfigurationError] = [
            .invalidConfidence(-0.5),
            .invalidDistance(0.05),
            .invalidBallDiameter(0.030),
            .invalidFrameRate(5),
            .invalidLatency(200),
            .invalidGPUUsage(80.0),
            .unsupportedHardware,
            .cameraPermissionDenied,
            .sensorUnavailable,
            .invalidParameterCombination("test"),
            .missingRequiredParameter("test"),
            .exceedsPlatformLimits("test")
        ]
        
        // All errors should have non-empty descriptions
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            
            XCTAssertNotNil(error.failureReason)
            XCTAssertFalse(error.failureReason!.isEmpty)
            
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    func testFailureReasons() {
        // Test that failure reasons provide detailed technical information
        let confidenceError = ConfigurationError.invalidConfidence(2.0)
        let failureReason = confidenceError.failureReason
        XCTAssertTrue(failureReason?.contains("normalized") == true)
        XCTAssertTrue(failureReason?.contains("0.0") == true)
        XCTAssertTrue(failureReason?.contains("1.0") == true)
        
        let hardwareError = ConfigurationError.unsupportedHardware
        XCTAssertTrue(hardwareError.failureReason?.contains("ARKit") == true)
        XCTAssertTrue(hardwareError.failureReason?.contains("processing power") == true)
    }
    
    func testRecoverySuggestions() {
        // Test that recovery suggestions provide actionable advice
        let permissionError = ConfigurationError.cameraPermissionDenied
        let suggestion = permissionError.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("Settings") == true)
        XCTAssertTrue(suggestion?.contains("Privacy") == true)
        XCTAssertTrue(suggestion?.contains("Camera") == true)
        
        let validationError = ConfigurationError.invalidConfidence(1.5)
        XCTAssertTrue(validationError.recoverySuggestion?.contains("input values") == true)
        XCTAssertTrue(validationError.recoverySuggestion?.contains("specified ranges") == true)
    }
    
    // MARK: - Error Categorization Tests
    
    func testIsRecoverable() {
        // Recoverable errors
        let recoverableErrors: [ConfigurationError] = [
            .invalidConfidence(1.5),
            .invalidDistance(15.0),
            .invalidBallDiameter(0.100),
            .invalidFrameRate(200),
            .invalidLatency(150),
            .invalidGPUUsage(75.0),
            .cameraPermissionDenied,
            .invalidParameterCombination("test"),
            .missingRequiredParameter("test"),
            .exceedsPlatformLimits("test")
        ]
        
        for error in recoverableErrors {
            XCTAssertTrue(error.isRecoverable, "\(error) should be recoverable")
        }
        
        // Non-recoverable errors
        let nonRecoverableErrors: [ConfigurationError] = [
            .unsupportedHardware,
            .sensorUnavailable
        ]
        
        for error in nonRecoverableErrors {
            XCTAssertFalse(error.isRecoverable, "\(error) should not be recoverable")
        }
    }
    
    func testErrorSeverity() {
        // Critical severity
        XCTAssertEqual(ConfigurationError.unsupportedHardware.severity, .critical)
        XCTAssertEqual(ConfigurationError.sensorUnavailable.severity, .critical)
        
        // High severity
        XCTAssertEqual(ConfigurationError.cameraPermissionDenied.severity, .high)
        
        // Medium severity
        XCTAssertEqual(ConfigurationError.invalidConfidence(1.5).severity, .medium)
        XCTAssertEqual(ConfigurationError.invalidDistance(15.0).severity, .medium)
        XCTAssertEqual(ConfigurationError.invalidBallDiameter(0.100).severity, .medium)
        XCTAssertEqual(ConfigurationError.invalidFrameRate(200).severity, .medium)
        XCTAssertEqual(ConfigurationError.invalidLatency(150).severity, .medium)
        XCTAssertEqual(ConfigurationError.invalidGPUUsage(75.0).severity, .medium)
        
        // Low severity
        XCTAssertEqual(ConfigurationError.invalidParameterCombination("test").severity, .low)
        XCTAssertEqual(ConfigurationError.missingRequiredParameter("test").severity, .low)
        XCTAssertEqual(ConfigurationError.exceedsPlatformLimits("test").severity, .low)
    }
    
    func testErrorCategory() {
        // Validation category
        let validationErrors: [ConfigurationError] = [
            .invalidConfidence(1.5),
            .invalidDistance(15.0),
            .invalidBallDiameter(0.100),
            .invalidFrameRate(200),
            .invalidLatency(150),
            .invalidGPUUsage(75.0)
        ]
        
        for error in validationErrors {
            XCTAssertEqual(error.category, .validation, "\(error) should be validation category")
        }
        
        // Hardware category
        XCTAssertEqual(ConfigurationError.unsupportedHardware.category, .hardware)
        XCTAssertEqual(ConfigurationError.sensorUnavailable.category, .hardware)
        
        // Permissions category
        XCTAssertEqual(ConfigurationError.cameraPermissionDenied.category, .permissions)
        
        // Configuration category
        XCTAssertEqual(ConfigurationError.invalidParameterCombination("test").category, .configuration)
        XCTAssertEqual(ConfigurationError.missingRequiredParameter("test").category, .configuration)
        XCTAssertEqual(ConfigurationError.exceedsPlatformLimits("test").category, .configuration)
    }
    
    // MARK: - Error Helper Tests
    
    func testErrorHelpers() {
        // Test invalidCombination helper
        let combinationError = ConfigurationError.invalidCombination("test description")
        if case .invalidParameterCombination(let description) = combinationError {
            XCTAssertEqual(description, "test description")
        } else {
            XCTFail("Expected invalidParameterCombination case")
        }
        
        // Test missingParameter helper
        let missingError = ConfigurationError.missingParameter("testParam")
        if case .missingRequiredParameter(let parameter) = missingError {
            XCTAssertEqual(parameter, "testParam")
        } else {
            XCTFail("Expected missingRequiredParameter case")
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testZeroValues() {
        // Test edge cases with zero values
        let zeroConfidence = ConfigurationError.invalidConfidence(0.0)
        XCTAssertNotNil(zeroConfidence.errorDescription)
        
        let zeroDistance = ConfigurationError.invalidDistance(0.0)
        XCTAssertTrue(zeroDistance.errorDescription?.contains("0.0") == true)
        
        let zeroLatency = ConfigurationError.invalidLatency(0)
        XCTAssertNotNil(zeroLatency.errorDescription)
    }
    
    func testNegativeValues() {
        // Test error handling with negative values
        let negativeConfidence = ConfigurationError.invalidConfidence(-1.0)
        XCTAssertTrue(negativeConfidence.errorDescription?.contains("-1") == true)
        
        let negativeDistance = ConfigurationError.invalidDistance(-5.0)
        XCTAssertTrue(negativeDistance.errorDescription?.contains("-5") == true)
        
        let negativeFPS = ConfigurationError.invalidFrameRate(-30)
        XCTAssertTrue(negativeFPS.errorDescription?.contains("-30") == true)
    }
    
    func testExtremeValues() {
        // Test error handling with extreme values
        let extremeConfidence = ConfigurationError.invalidConfidence(Float.infinity)
        XCTAssertNotNil(extremeConfidence.errorDescription)
        
        let extremeDistance = ConfigurationError.invalidDistance(1000.0)
        XCTAssertTrue(extremeDistance.errorDescription?.contains("1000") == true)
        
        let extremeLatency = ConfigurationError.invalidLatency(Int.max)
        XCTAssertNotNil(extremeLatency.errorDescription)
    }
    
    // MARK: - Error Pattern Tests
    
    func testErrorPatternMatching() {
        let errors: [ConfigurationError] = [
            .invalidConfidence(1.5),
            .unsupportedHardware,
            .invalidParameterCombination("test")
        ]
        
        for error in errors {
            switch error {
            case .invalidConfidence(let value):
                XCTAssertEqual(value, 1.5, accuracy: 0.001)
            case .unsupportedHardware:
                XCTAssertEqual(error.severity, .critical)
            case .invalidParameterCombination(let description):
                XCTAssertEqual(description, "test")
            default:
                XCTFail("Unexpected error case: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testErrorEquality() {
        // Test that identical errors are equal (when possible)
        let error1 = ConfigurationError.invalidConfidence(1.5)
        let error2 = ConfigurationError.invalidConfidence(1.5)
        
        // Note: ConfigurationError doesn't conform to Equatable by default
        // This test verifies the structure allows for comparison
        switch (error1, error2) {
        case (.invalidConfidence(let val1), .invalidConfidence(let val2)):
            XCTAssertEqual(val1, val2, accuracy: 0.001)
        default:
            XCTFail("Errors should be the same type")
        }
        
        // Test hardware errors
        let hw1 = ConfigurationError.unsupportedHardware
        let hw2 = ConfigurationError.unsupportedHardware
        
        switch (hw1, hw2) {
        case (.unsupportedHardware, .unsupportedHardware):
            break // Success
        default:
            XCTFail("Hardware errors should match")
        }
    }
    
    func testErrorWithAppConfiguration() {
        // Test errors that could arise from AppConfiguration usage
        let invalidConf = AppConfiguration.confidenceThreshold + 0.5 // 1.35
        let confError = ConfigurationError.invalidConfidence(invalidConf)
        
        // This should be recoverable since it's a validation error
        XCTAssertTrue(confError.isRecoverable)
        XCTAssertEqual(confError.category, .validation)
        XCTAssertEqual(confError.severity, .medium)
    }
    
    // MARK: - Performance Tests
    
    func testErrorCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = ConfigurationError.invalidConfidence(Float(i))
                let _ = ConfigurationError.unsupportedHardware
                let _ = ConfigurationError.invalidParameterCombination("test")
            }
        }
    }
    
    func testErrorDescriptionPerformance() {
        let errors: [ConfigurationError] = [
            .invalidConfidence(1.5),
            .invalidDistance(15.0),
            .unsupportedHardware,
            .cameraPermissionDenied,
            .invalidParameterCombination("test combination"),
            .missingRequiredParameter("testParam")
        ]
        
        measure {
            for _ in 0..<1000 {
                for error in errors {
                    let _ = error.errorDescription
                    let _ = error.failureReason
                    let _ = error.recoverySuggestion
                }
            }
        }
    }
}