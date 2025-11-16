import XCTest
@testable import CueDot

/// Comprehensive tests for TrackingState and related enums
/// Validates state transitions, user descriptions, and reliability assessments
class TrackingStateTests: XCTestCase {
    
    // MARK: - Basic State Tests
    
    func testNormalTrackingState() {
        // Given
        let state = TrackingState.normal
        
        // When & Then
        XCTAssertTrue(state.isReliableForOverlay)
        XCTAssertEqual(state.severity, .none)
        XCTAssertEqual(state.userDescription, "Tracking normally")
        XCTAssertEqual(state.description, "TrackingState.normal")
    }
    
    // MARK: - Limited Tracking Tests
    
    func testLimitedTrackingInsufficientFeatures() {
        // Given
        let state = TrackingState.limited(reason: .insufficientFeatures)
        
        // When & Then
        XCTAssertTrue(state.isReliableForOverlay, "Insufficient features should still allow overlays")
        XCTAssertEqual(state.severity, .warning)
        XCTAssertTrue(state.userDescription.contains("textured surfaces"))
    }
    
    func testLimitedTrackingExcessiveMotion() {
        // Given
        let state = TrackingState.limited(reason: .excessiveMotion)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay, "Excessive motion should prevent overlays")
        XCTAssertEqual(state.severity, .caution)
        XCTAssertTrue(state.userDescription.contains("more slowly"))
    }
    
    func testLimitedTrackingPoorLighting() {
        // Given
        let state = TrackingState.limited(reason: .poorLighting)
        
        // When & Then
        XCTAssertTrue(state.isReliableForOverlay, "Poor lighting should still allow overlays")
        XCTAssertEqual(state.severity, .warning)
        XCTAssertTrue(state.userDescription.contains("lighting"))
    }
    
    func testLimitedTrackingInitializing() {
        // Given
        let state = TrackingState.limited(reason: .initializing)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay, "Initializing should prevent overlays")
        XCTAssertEqual(state.severity, .caution)
        XCTAssertTrue(state.userDescription.contains("Initializing"))
    }
    
    func testLimitedTrackingSensorIssues() {
        // Given
        let state = TrackingState.limited(reason: .sensorIssues)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay, "Sensor issues should prevent overlays")
        XCTAssertEqual(state.severity, .caution)
        XCTAssertTrue(state.userDescription.contains("calibration"))
    }
    
    // MARK: - Not Available Tracking Tests
    
    func testNotAvailableCameraUnavailable() {
        // Given
        let state = TrackingState.notAvailable(reason: .cameraUnavailable)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay)
        XCTAssertEqual(state.severity, .critical)
        XCTAssertTrue(state.userDescription.contains("Camera unavailable"))
        XCTAssertTrue(state.userDescription.contains("permissions"))
    }
    
    func testNotAvailableUnsupportedConfiguration() {
        // Given
        let state = TrackingState.notAvailable(reason: .unsupportedConfiguration)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay)
        XCTAssertEqual(state.severity, .critical)
        XCTAssertTrue(state.userDescription.contains("not supported"))
    }
    
    func testNotAvailableSessionInterrupted() {
        // Given
        let state = TrackingState.notAvailable(reason: .sessionInterrupted)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay)
        XCTAssertEqual(state.severity, .critical)
        XCTAssertTrue(state.userDescription.contains("interrupted"))
    }
    
    func testNotAvailableSensorFailure() {
        // Given
        let state = TrackingState.notAvailable(reason: .sensorFailure)
        
        // When & Then
        XCTAssertFalse(state.isReliableForOverlay)
        XCTAssertEqual(state.severity, .critical)
        XCTAssertTrue(state.userDescription.contains("sensor error"))
    }
    
    // MARK: - Equatable Tests
    
    func testEquality_NormalStates() {
        // Given
        let state1 = TrackingState.normal
        let state2 = TrackingState.normal
        
        // When & Then
        XCTAssertEqual(state1, state2)
    }
    
    func testEquality_SameLimitedReason() {
        // Given
        let state1 = TrackingState.limited(reason: .insufficientFeatures)
        let state2 = TrackingState.limited(reason: .insufficientFeatures)
        
        // When & Then
        XCTAssertEqual(state1, state2)
    }
    
    func testInequality_DifferentLimitedReasons() {
        // Given
        let state1 = TrackingState.limited(reason: .insufficientFeatures)
        let state2 = TrackingState.limited(reason: .excessiveMotion)
        
        // When & Then
        XCTAssertNotEqual(state1, state2)
    }
    
    func testEquality_SameUnavailableReason() {
        // Given
        let state1 = TrackingState.notAvailable(reason: .cameraUnavailable)
        let state2 = TrackingState.notAvailable(reason: .cameraUnavailable)
        
        // When & Then
        XCTAssertEqual(state1, state2)
    }
    
    func testInequality_DifferentUnavailableReasons() {
        // Given
        let state1 = TrackingState.notAvailable(reason: .cameraUnavailable)
        let state2 = TrackingState.notAvailable(reason: .sessionInterrupted)
        
        // When & Then
        XCTAssertNotEqual(state1, state2)
    }
    
    func testInequality_DifferentMainStates() {
        // Given
        let normal = TrackingState.normal
        let limited = TrackingState.limited(reason: .insufficientFeatures)
        let unavailable = TrackingState.notAvailable(reason: .cameraUnavailable)
        
        // When & Then
        XCTAssertNotEqual(normal, limited)
        XCTAssertNotEqual(normal, unavailable)
        XCTAssertNotEqual(limited, unavailable)
    }
    
    // MARK: - Description Tests
    
    func testLimitedTrackingDescription() {
        // Given
        let state = TrackingState.limited(reason: .excessiveMotion)
        
        // When
        let description = state.description
        
        // Then
        XCTAssertEqual(description, "TrackingState.limited(excessiveMotion)")
    }
    
    func testNotAvailableDescription() {
        // Given
        let state = TrackingState.notAvailable(reason: .sensorFailure)
        
        // When
        let description = state.description
        
        // Then
        XCTAssertEqual(description, "TrackingState.notAvailable(sensorFailure)")
    }
    
    // MARK: - Reason Enum Tests
    
    func testLimitedTrackingReasonDescriptions() {
        let reasons: [LimitedTrackingReason] = [
            .insufficientFeatures,
            .excessiveMotion,
            .poorLighting,
            .initializing,
            .sensorIssues
        ]
        
        for reason in reasons {
            XCTAssertFalse(reason.description.isEmpty, "Description should not be empty for \(reason)")
        }
    }
    
    func testUnavailableReasonDescriptions() {
        let reasons: [UnavailableReason] = [
            .cameraUnavailable,
            .unsupportedConfiguration,
            .sessionInterrupted,
            .sensorFailure
        ]
        
        for reason in reasons {
            XCTAssertFalse(reason.description.isEmpty, "Description should not be empty for \(reason)")
        }
    }
    
    // MARK: - Severity Tests
    
    func testSeverityProgression() {
        // Test that severity increases appropriately
        let normal = TrackingState.normal
        let limitedWarning = TrackingState.limited(reason: .insufficientFeatures)
        let limitedCaution = TrackingState.limited(reason: .excessiveMotion)
        let critical = TrackingState.notAvailable(reason: .cameraUnavailable)
        
        XCTAssertEqual(normal.severity, .none)
        XCTAssertEqual(limitedWarning.severity, .warning)
        XCTAssertEqual(limitedCaution.severity, .caution)
        XCTAssertEqual(critical.severity, .critical)
    }
    
    // MARK: - Test Helper Tests (Debug Only)
    
    func testTestHelpers() {
        // Test normal state helper
        let normalState = TrackingState.testNormal
        XCTAssertEqual(normalState, .normal)
        XCTAssertTrue(normalState.isReliableForOverlay)
        
        // Test limited state helper
        let limitedState = TrackingState.testLimitedFeatures
        XCTAssertEqual(limitedState, .limited(reason: .insufficientFeatures))
        XCTAssertTrue(limitedState.isReliableForOverlay) // Insufficient features still allows overlay
        
        // Test unavailable state helper
        let unavailableState = TrackingState.testUnavailableCamera
        XCTAssertEqual(unavailableState, .notAvailable(reason: .cameraUnavailable))
        XCTAssertFalse(unavailableState.isReliableForOverlay)
    }
    
    // MARK: - Comprehensive State Coverage
    
    func testAllLimitedReasonsCovered() {
        // Ensure all limited tracking reasons are handled in computed properties
        let allReasons: [LimitedTrackingReason] = [
            .insufficientFeatures,
            .excessiveMotion,
            .poorLighting,
            .initializing,
            .sensorIssues
        ]
        
        for reason in allReasons {
            let state = TrackingState.limited(reason: reason)
            
            // Should have valid descriptions and severity
            XCTAssertFalse(state.userDescription.isEmpty)
            XCTAssertNotEqual(state.severity, .none) // Limited states should never be "none"
            
            // isReliableForOverlay should be deterministic
            let reliability = state.isReliableForOverlay
            XCTAssertNotNil(reliability) // Just ensuring it doesn't crash
        }
    }
    
    func testAllUnavailableReasonsCovered() {
        // Ensure all unavailable reasons are handled
        let allReasons: [UnavailableReason] = [
            .cameraUnavailable,
            .unsupportedConfiguration,
            .sessionInterrupted,
            .sensorFailure
        ]
        
        for reason in allReasons {
            let state = TrackingState.notAvailable(reason: reason)
            
            // Should have valid descriptions and critical severity
            XCTAssertFalse(state.userDescription.isEmpty)
            XCTAssertEqual(state.severity, .critical)
            XCTAssertFalse(state.isReliableForOverlay) // Unavailable should never be reliable
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfReliabilityCheck() {
        let states: [TrackingState] = [
            .normal,
            .limited(reason: .insufficientFeatures),
            .limited(reason: .excessiveMotion),
            .notAvailable(reason: .cameraUnavailable)
        ]
        
        // Measure performance of reliability checks
        measure {
            for _ in 0..<10000 {
                for state in states {
                    _ = state.isReliableForOverlay
                }
            }
        }
    }
}