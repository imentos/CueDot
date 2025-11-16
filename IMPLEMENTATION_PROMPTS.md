# AR Cue Alignment Coach - Implementation Prompts

This document contains 20 carefully crafted implementation prompts for building the AR Cue Alignment Coach application using test-driven development in Swift.

---

## Phase 1: Foundation & Core Models (Steps 1-4)

### Step 1: Project Setup & Core Data Models

```
Create the foundational iOS project structure and core data models for an AR cue ball detection application in Swift.

Requirements:
- Create iOS project targeting iOS 17+ with Swift 5.9
- Set up folder structure: Models/, Vision/, AR/, UI/, Core/
- Create BallDetectionResult struct with:
  - ballCenter3D: SIMD3<Float> (world coordinates)
  - confidence: Float (0.0-1.0)
  - timestamp: TimeInterval
  - isOccluded: Bool
  - hasMultipleBalls: Bool
  - Implement Equatable for testing
- Create TrackingState enum: .normal, .limited, .notAvailable
- Add proper Swift documentation comments
- Create unit tests validating model properties and equality
- Ensure models compile without errors

Deliverables:
- Complete project structure with proper Swift conventions
- Models/BallDetectionResult.swift with comprehensive tests
- Models/TrackingState.swift with enum cases
- Tests/ folder with >95% coverage of models
- All tests passing with zero compiler warnings
```

### Step 2: Configuration System & Constants

```
Create a type-safe configuration system matching the specification requirements using Swift's strong typing.

Requirements:
- Create AppConfiguration struct with static constants:
  - confidenceThreshold: Float = 0.85
  - jitterThreshold: Float = 0.002 (2mm in meters)
  - emaAlpha: Float = 0.5
  - overlayColor: UIColor = .systemRed (#FF0000)
  - dotDiameterRatio: Float = 0.06
  - crosshairLengthRatio: Float = 0.22
  - standardBallDiameter: Float = 0.057 (57mm)
- Add computed properties for derived values
- Create ConfigurationError enum for validation failures
- Implement validation methods ensuring values are within reasonable ranges
- Add comprehensive unit tests validating all constants match specification
- Create performance constants (targetFPS: 60, maxLatencyMS: 60, etc.)

Deliverables:
- Core/AppConfiguration.swift with type-safe constants
- Core/ConfigurationError.swift for error handling
- Comprehensive unit tests validating specification compliance
- Documentation explaining each configuration parameter
- All validation tests passing
```

### Step 3: Test Infrastructure & Utilities

```
Create comprehensive test infrastructure with utilities for testing AR and Vision components in Swift.

Requirements:
- Set up XCTest target with proper configuration
- Create TestHelpers.swift with utilities:
  - SIMD3<Float> equality with epsilon comparison
  - Mock BallDetectionResult generators
  - Async test helpers for Vision/AR testing
  - Performance measurement utilities
- Create MockData.swift with realistic test scenarios:
  - Stable tracking sequences
  - Jittery motion patterns
  - Confidence fade scenarios
  - Multi-ball detection cases
- Add BaseTestCase class extending XCTestCase:
  - Common setup/teardown for AR testing
  - Memory leak detection
  - Performance benchmarking helpers
- Create test data validation ensuring mock data is realistic

Deliverables:
- Tests/TestHelpers.swift with comprehensive utilities
- Tests/MockData.swift with realistic test scenarios
- Tests/BaseTestCase.swift with common test functionality
- All test utilities working correctly
- Documentation for using test infrastructure
```

### Step 4: Protocol Definitions & Interfaces

```
Define the core protocols and interfaces that will structure the application architecture using Swift protocols.

Requirements:
- Create BallDetectionProtocol with async detection method:
  - func detectBall(in pixelBuffer: CVPixelBuffer) async throws -> BallDetectionResult
- Create BallTrackingProtocol for position smoothing:
  - func updateTracking(with result: BallDetectionResult) -> TrackingResult
- Create ARSessionProtocol for testable AR integration:
  - Properties for tracking state and camera transform
  - Methods for session lifecycle management
- Define TrackingResult struct combining smoothed position and visibility state
- Create protocol conformance tests using mock implementations
- Add comprehensive documentation explaining each protocol's responsibilities

Deliverables:
- Vision/BallDetectionProtocol.swift with async detection interface
- Vision/BallTrackingProtocol.swift for tracking abstraction
- AR/ARSessionProtocol.swift for testable AR integration
- Models/TrackingResult.swift for tracking output
- Protocol conformance tests ensuring interfaces work correctly
- Clear documentation of architectural contracts
```

---

## Phase 2: Vision Detection Pipeline (Steps 5-8)

### Step 5: Mock Vision Detector for Testing

```
Create a comprehensive mock implementation of ball detection for testing and early integration in Swift.

Requirements:
- Create MockVisionDetector conforming to BallDetectionProtocol
- Support configurable behavior via MockDetectionBehavior:
  - Sequence of detection results to return
  - Simulated processing delay (async)
  - Occlusion and multi-ball simulation flags
- Generate realistic motion sequences:
  - Stable tracking with minor variations
  - Jittery motion exceeding 2mm threshold
  - Confidence fading from high to low
  - Multi-ball scenarios
- Implement proper async/await patterns
- Add comprehensive unit tests validating all mock behaviors
- Include timing simulation matching real Vision performance

Deliverables:
- Vision/MockVisionDetector.swift with full mock implementation
- Vision/MockDetectionBehavior.swift for configuration
- Realistic motion simulation methods
- Unit tests covering all mock scenarios
- Async pattern implementation following Swift concurrency best practices
- Performance timing matching specification (25-30ms simulation)
```

### Step 6: Vision Framework Ball Detection

```
Implement actual ball detection using Vision framework with circle detection and color filtering in Swift.

Requirements:
- Create VisionBallDetector conforming to BallDetectionProtocol
- Use VNDetectCirclesRequest for circle detection:
  - Configure radius constraints based on expected ball size
  - Set appropriate confidence thresholds
  - Handle multiple circle results
- Implement white cue ball color filtering:
  - Convert regions to HSV color space
  - Filter for high brightness, low saturation
  - Calculate color confidence score
- Add size validation and boundary proximity checks
- Implement comprehensive error handling with Swift Result types
- Create unit tests using test images of cue balls
- Optimize performance for real-time operation

Deliverables:
- Vision/VisionBallDetector.swift with Vision framework integration
- Vision/ColorFilterUtils.swift for cue ball color detection
- Comprehensive error handling using Swift Result patterns
- Unit tests with test images validation
- Performance benchmarks showing <30ms detection time
- Color filtering achieving high accuracy for white balls
```

### Step 7: Multi-ball Detection & Clustering

```
Enhance ball detection to handle multiple white balls with proper clustering and selection logic in Swift.

Requirements:
- Extend VisionBallDetector for multiple candidate detection
- Implement BallCluster struct for grouping nearby detections:
  - Distance-based clustering (ball radius * 1.5 threshold)
  - Confidence-based selection within clusters
  - Proper handling of cluster merging/splitting
- Add multi-ball decision logic:
  - Single ball: normal operation
  - Zero balls: confidence 0.0
  - Multiple balls: hasMultipleBalls = true, confidence 0.0
- Implement frame-to-frame tracking for detection stability
- Create comprehensive unit tests for all clustering scenarios
- Add debugging support for visualization during development

Deliverables:
- Enhanced Vision/VisionBallDetector.swift with multi-ball handling
- Vision/BallCluster.swift for detection grouping
- Vision/FrameTracker.swift for temporal consistency
- Unit tests covering all multi-ball scenarios
- Clustering algorithm optimized for real-time performance
- Debug visualization utilities for development
```

### Step 8: Confidence Calculation & Validation

```
Implement sophisticated confidence scoring system meeting specification accuracy requirements in Swift.

Requirements:
- Create ConfidenceCalculator with weighted scoring components:
  - Circle detection quality (0.0-1.0 from Vision)
  - Color matching score (white vs other colors)
  - Size consistency (expected vs detected size)
  - Temporal stability across frames
  - Edge proximity penalty
- Implement ConfidenceWeights struct for tunable parameters
- Add detection validation logic rejecting impossible detections
- Create calibration system for confidence threshold tuning
- Implement comprehensive unit tests with ground truth validation
- Add performance metrics ensuring minimal computational overhead

Deliverables:
- Vision/ConfidenceCalculator.swift with modular scoring
- Vision/ConfidenceWeights.swift for parameter tuning
- Vision/DetectionValidator.swift for sanity checking
- Comprehensive unit tests with accuracy validation
- Calibration utilities for threshold optimization
- Performance validation showing minimal impact on detection speed
```

---

## Phase 3: Tracking & State Management (Steps 9-12)

### Step 9: EMA Smoothing Filter Implementation

```
Create a robust exponential moving average filter for 3D position smoothing in Swift using SIMD types.

Requirements:
- Create EMAFilter class for SIMD3<Float> smoothing:
  - Configurable alpha parameter (spec: 0.5)
  - Proper first-frame initialization handling
  - Thread-safe implementation for real-time use
  - Reset functionality for new tracking sequences
- Implement smoothing algorithm: newFiltered = α * current + (1 - α) * previous
- Add comprehensive unit tests:
  - Stable input convergence
  - Noisy input variation reduction
  - Alpha parameter sensitivity
  - Edge cases (NaN, infinity, first frame)
- Create performance benchmarks ensuring <1ms latency
- Add visualization helpers for development debugging

Deliverables:
- Vision/EMAFilter.swift with complete smoothing implementation
- Comprehensive unit tests covering all scenarios
- Performance benchmarks proving <1ms operation
- Thread-safe implementation supporting 60fps operation
- Debug utilities for visualizing smoothing effectiveness
- Documentation explaining smoothing parameters and tuning
```

### Step 10: Jitter Detection State Machine

```
Implement jitter detection and position freeze logic using Swift's enum-based state machine pattern.

Requirements:
- Create JitterDetector class with clear state machine:
  - JitterState enum: .normal, .detecting, .frozen
  - Track consecutive high-displacement frames (>2mm threshold)
  - Implement 3-frame trigger, 5-frame freeze as specified
  - Clean state transitions with proper timing
- Add displacement calculation using SIMD distance functions
- Implement comprehensive state machine testing:
  - Normal operation with small movements
  - Jitter trigger with large consecutive movements
  - Freeze behavior maintaining position
  - Recovery after freeze period
- Create performance validation ensuring minimal latency impact
- Add debug logging for state transitions

Deliverables:
- Vision/JitterDetector.swift with complete state machine
- Vision/JitterState.swift with enum definitions
- Comprehensive state machine tests covering all transitions
- Performance validation showing <1ms overhead
- State transition logging for debugging
- Documentation explaining jitter parameters and behavior
```

### Step 11: Ball Tracker Integration

```
Create the main BallTracker class integrating EMA smoothing and jitter detection following Swift composition patterns.

Requirements:
- Implement BallTracker conforming to BallTrackingProtocol:
  - Compose EMAFilter and JitterDetector instances
  - Handle confidence-based visibility decisions
  - Manage tracking state transitions
  - Output TrackingResult with stabilized data
- Add TrackingQuality enum for overall tracking assessment
- Implement confidence history tracking for trend analysis
- Create comprehensive integration tests:
  - End-to-end pipeline from detection to tracking result
  - Smoothing + jitter interaction validation
  - Confidence-based visibility transitions
- Add performance monitoring for complete tracking pipeline
- Ensure thread-safe operation for real-time use

Deliverables:
- Vision/BallTracker.swift with complete tracking integration
- Models/TrackingQuality.swift for quality assessment
- Integration tests validating complete pipeline
- Performance benchmarks for end-to-end tracking (<5ms)
- Thread-safe implementation ready for AR integration
- Comprehensive documentation of tracking behavior
```

### Step 12: Tracking State Management System

```
Implement comprehensive state management preventing overlay flicker and handling edge cases in Swift.

Requirements:
- Create TrackingStateManager with state machine:
  - TrackingMode enum: .acquiring, .tracking, .uncertain, .lost, .frozen
  - Hysteresis logic preventing rapid state changes
  - Confidence-based transition thresholds
  - Recovery logic from lost tracking
- Implement state transition rules with timing constraints:
  - Multiple frames of good confidence before showing overlay
  - Multiple frames of poor confidence before hiding
  - Smooth transitions preventing flicker
- Add comprehensive state testing covering all transitions
- Create integration with jitter freeze states
- Implement debug utilities for state visualization
- Add performance validation for state management overhead

Deliverables:
- Vision/TrackingStateManager.swift with complete state machine
- Models/TrackingMode.swift with state definitions
- Comprehensive state transition tests
- Integration with jitter detection states
- State visualization utilities for debugging
- Performance validation showing minimal overhead
```

---

## Phase 4: AR Integration & Coordinate Systems (Steps 13-16)

### Step 13: ARKit Session Foundation

```
Create foundational ARKit session management with proper Swift delegate patterns and error handling.

Requirements:
- Create ARSessionManager conforming to ARSessionProtocol:
  - ARSession lifecycle management
  - World tracking configuration optimized for 60fps
  - Proper delegate pattern implementation
  - Comprehensive error handling
- Implement ARSessionState enum for session status tracking
- Add session configuration for optimal performance:
  - World tracking with plane detection
  - Camera resolution settings
  - Lighting estimation configuration
- Create unit tests using ARKit mocking
- Add integration tests for session lifecycle
- Implement proper cleanup and memory management

Deliverables:
- AR/ARSessionManager.swift with complete session management
- AR/ARSessionState.swift for status tracking
- Comprehensive error handling for ARKit failures
- Unit tests with ARKit mocking
- Session configuration optimized for specification requirements
- Proper resource management and cleanup
```

### Step 14: Camera Transform & Coordinate Conversion

```
Implement camera transform extraction and coordinate conversion utilities for accurate AR positioning in Swift.

Requirements:
- Create CameraTransformProvider for transform extraction:
  - Current camera transform from ARFrame
  - Camera intrinsics for projection calculations
  - Device orientation handling
  - Transform validation and error detection
- Implement CoordinateConverter utility class:
  - 2D screen space to 3D world space conversion
  - 3D world space to 2D screen projection
  - Proper coordinate system handling (ARKit vs SceneKit)
  - Distance and scale calculations
- Add comprehensive unit tests with known test cases
- Create performance optimizations for real-time operation
- Add coordinate system documentation and examples

Deliverables:
- AR/CameraTransformProvider.swift for transform management
- AR/CoordinateConverter.swift for space conversions
- Comprehensive unit tests with coordinate accuracy validation
- Performance optimizations for 60fps operation
- Documentation explaining coordinate systems and usage
- Error handling for invalid transforms
```

### Step 15: Plane Detection & Ball Positioning

```
Implement ARKit plane detection integration for improved ball positioning accuracy using Swift's ARKit APIs.

Requirements:
- Extend ARSessionManager with plane detection:
  - Horizontal plane detection configuration
  - ARPlaneAnchor monitoring and management
  - Plane validation (size, orientation, stability)
  - Table plane selection logic
- Create PlaneManager for plane tracking:
  - Active plane database
  - Plane quality scoring
  - Plane-based ball positioning
  - Fallback positioning without planes
- Implement ball-to-plane projection calculations
- Add comprehensive testing with simulated planes
- Create debugging visualization for plane detection
- Ensure graceful fallback when planes unavailable

Deliverables:
- Enhanced AR/ARSessionManager.swift with plane detection
- AR/PlaneManager.swift for plane tracking and selection
- AR/PlanePositioning.swift for ball positioning calculations
- Unit tests with simulated plane scenarios
- Debug visualization utilities
- Fallback positioning maintaining accuracy without planes
```

### Step 16: AR Tracking State Monitoring

```
Implement ARKit tracking state monitoring with re-calibration logic matching specification timing in Swift.

Requirements:
- Create ARTrackingMonitor with timing-based logic:
  - Monitor ARCamera.trackingState changes
  - Timer management for degraded states
  - 2-second relight trigger, 5-second realign warning
  - State change event broadcasting
- Implement TrackingEvent enum for state notifications:
  - trackingImproved, trackingDegraded, relightTriggered, realignRequired
  - Proper event timing and debouncing
  - Observer pattern for event distribution
- Add comprehensive timing tests:
  - State transition validation
  - Timer accuracy verification
  - Event delivery testing
- Create integration with session management
- Add debugging utilities for tracking state visualization

Deliverables:
- AR/ARTrackingMonitor.swift with timing logic
- AR/TrackingEvent.swift for event definitions
- Comprehensive timing tests validating specification compliance
- Observer pattern for event distribution
- Integration with ARSessionManager
- Debug utilities for tracking state visualization
```

---

## Phase 5: Final Assembly & Integration (Steps 17-20)

### Step 17: SceneKit Overlay Foundation

```
Create the SceneKit-based overlay rendering foundation optimized for AR performance in Swift.

Requirements:
- Create OverlayRenderer class with ARSCNView integration:
  - Scene setup optimized for AR overlays
  - Performance configuration (antialiasing, lighting)
  - Node management for dynamic overlays
  - GPU usage monitoring and optimization
- Implement CrosshairNode as SCNNode subclass:
  - Geometry generation for center dot + crosshair
  - Material configuration (#FF0000, opacity 0.9)
  - Billboard behavior facing camera
  - Proper depth handling preventing z-fighting
- Add SceneKit performance optimizations:
  - Efficient geometry generation
  - Minimal draw calls
  - Proper material sharing
- Create comprehensive rendering tests
- Add performance monitoring for GPU usage

Deliverables:
- AR/OverlayRenderer.swift with SceneKit foundation
- AR/CrosshairNode.swift with complete geometry implementation
- Performance optimizations meeting GPU budget (<15%)
- Comprehensive rendering tests
- GPU usage monitoring and validation
- Material and geometry optimization for real-time rendering
```

### Step 18: Dynamic Overlay Updates & Animation

```
Implement real-time overlay positioning with smooth updates and visibility management in Swift.

Requirements:
- Create OverlayUpdateManager for real-time updates:
  - Position updates from TrackingResult
  - Smooth interpolation for position changes
  - Size scaling based on camera distance
  - Visibility state management
- Implement VisibilityAnimator for smooth transitions:
  - Fade in/out with specified 0.3s duration
  - Immediate hide for occlusion/low confidence
  - Scale animation support for future features
  - Core Animation integration
- Add distance-based size scaling:
  - Consistent visual size regardless of distance
  - Proper scaling calculations
  - Minimum/maximum size constraints
- Create comprehensive animation tests
- Add performance validation for 60fps updates

Deliverables:
- AR/OverlayUpdateManager.swift with real-time positioning
- AR/VisibilityAnimator.swift for smooth transitions
- AR/SizeScaling.swift for distance-based scaling
- Comprehensive animation and positioning tests
- Performance validation for 60fps operation
- Smooth overlay behavior meeting specification requirements
```

### Step 19: Warning UI & Debug Panel

```
Create the warning UI system and debug panel with gesture activation using UIKit and Swift.

Requirements:
- Create WarningUIController for overlay warnings:
  - Icon-based warnings (occlusion, multi-ball, tracking lost)
  - Non-intrusive positioning over AR view
  - Auto-dismiss behavior when conditions resolve
  - Priority system for multiple warnings
- Implement DebugPanelController with gesture activation:
  - Triple-tap gesture recognition
  - Real-time metrics display (confidence, latency, FPS)
  - Performance monitoring integration
  - Minimal performance impact when hidden
- Create WarningType enum for different warning states
- Add comprehensive UI testing
- Implement proper UIKit integration with ARSCNView
- Add accessibility support for warnings

Deliverables:
- UI/WarningUIController.swift with complete warning system
- UI/DebugPanelController.swift with gesture-activated panel
- UI/WarningType.swift for warning definitions
- Comprehensive UI tests covering all warning scenarios
- Accessibility support for warning messages
- Performance validation showing minimal UI overhead
```

### Step 20: Main Application Integration & Performance Monitoring

```
Complete the application by integrating all components and implementing comprehensive performance monitoring in Swift.

Requirements:
- Create CueDotCoordinator as main application coordinator:
  - Initialize and coordinate all major components
  - Pipeline: VisionDetector -> BallTracker -> OverlayRenderer
  - Error handling and recovery logic
  - Application lifecycle management
- Integrate all components with proper dependency injection:
  - Protocol-based architecture enabling testability
  - Clear separation of concerns
  - Proper error propagation and handling
- Implement PerformanceMonitor tracking specification requirements:
  - End-to-end latency measurement (target <30ms)
  - Frame rate monitoring (target 60fps)
  - CPU/GPU usage tracking
  - Memory usage validation
- Create comprehensive integration tests
- Add final performance validation against all specification requirements

Deliverables:
- Core/CueDotCoordinator.swift with complete application coordination
- Core/PerformanceMonitor.swift with specification validation
- Comprehensive integration tests for complete pipeline
- Performance benchmarks meeting all specification requirements
- Complete application ready for deployment
- Documentation covering architecture and usage
```

---

## Implementation Guidelines

### Test-Driven Development
- Write tests first, then implement functionality
- Maintain >90% code coverage
- Use Swift's type system for compile-time safety
- Include performance tests for critical paths

### Swift Best Practices
- Leverage protocols for testability and modularity
- Use value types (structs) for data models
- Employ enums with associated values for state management
- Utilize async/await for asynchronous operations

### Performance Considerations
- Continuous monitoring against specification requirements
- Use instruments for performance profiling
- Optimize for sustained 60fps operation
- Monitor memory usage and prevent leaks

### Integration Strategy
- Each step builds incrementally on previous work
- No orphaned or unused code
- Clear integration points between components
- Comprehensive end-to-end testing

This blueprint provides a complete roadmap for building the AR Cue Alignment Coach application through 20 carefully planned implementation steps, ensuring high quality, performance, and maintainability.