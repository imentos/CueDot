import Foundation
import simd
#if canImport(ARKit)
import ARKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Mock ARView for testing AR components without requiring real ARKit hardware
/// Provides controllable AR session simulation, synthetic frame data, and state management
@available(iOS 17.0, *)
public class MockARView {
    
    // MARK: - Public Properties
    
    /// Current tracking state of the mock AR session
    public private(set) var trackingState: TrackingState = .normal
    
    /// Whether the AR session is currently running
    public private(set) var isSessionRunning = false
    
    /// Current camera transform in world space
    public private(set) var cameraTransform = matrix_identity_float4x4
    
    /// Current lighting conditions (0.0 to 1.0)
    public private(set) var lightingConditions: Float = 0.8
    
    /// Mock view bounds for testing
    public var bounds = CGRect(x: 0, y: 0, width: 390, height: 844) // iPhone 14 Pro dimensions
    
    /// Current frame timestamp
    public private(set) var currentFrameTimestamp: TimeInterval = 0.0
    
    /// Configuration for mock behavior
    public let configuration: MockARConfiguration
    
    // MARK: - Internal Properties
    
    /// Frame provider for synthetic data
    private let frameProvider: ARFrameProvider
    
    /// Performance profiler for metrics tracking
    private let performanceProfiler: PerformanceProfiler
    
    /// Timer for frame generation
    private var frameTimer: Timer?
    
    /// Session start time
    private var sessionStartTime: Date?
    
    /// Frame counter for synthetic data generation
    private var frameCounter: UInt64 = 0
    
    /// List of mock detected balls
    private var mockDetections: [BallDetectionResult] = []
    
    /// Callbacks for session events
    private var sessionCallbacks: [MockARSessionCallback] = []
    
    // MARK: - Initialization
    
    /// Initialize MockARView with configuration
    /// - Parameter configuration: Configuration for mock behavior
    public init(configuration: MockARConfiguration = MockARConfiguration()) {
        self.configuration = configuration
        self.frameProvider = ARFrameProvider(configuration: configuration.frameConfig)
        self.performanceProfiler = PerformanceProfiler()
        
        setupInitialState()
    }
    
    // MARK: - AR Session Control
    
    /// Start the mock AR session
    /// - Parameter completion: Called when session starts with success/failure
    public func startSession(completion: @escaping (Bool) -> Void = { _ in }) {
        guard !isSessionRunning else {
            completion(false)
            return
        }
        
        performanceProfiler.startProfiling()
        sessionStartTime = Date()
        isSessionRunning = true
        frameCounter = 0
        currentFrameTimestamp = 0.0
        
        // Simulate session initialization delay
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.sessionStartDelay) {
            self.updateTrackingState(.normal)
            self.startFrameGeneration()
            completion(true)
            self.notifySessionStarted()
        }
    }
    
    /// Stop the mock AR session
    /// - Parameter completion: Called when session stops
    public func stopSession(completion: @escaping () -> Void = {}) {
        guard isSessionRunning else {
            completion()
            return
        }
        
        stopFrameGeneration()
        isSessionRunning = false
        sessionStartTime = nil
        performanceProfiler.stopProfiling()
        
        updateTrackingState(.notAvailable(reason: .sessionInterrupted))
        notifySessionStopped()
        completion()
    }
    
    /// Pause the mock AR session
    public func pauseSession() {
        guard isSessionRunning else { return }
        stopFrameGeneration()
        updateTrackingState(.limited(reason: .initializing))
        notifySessionPaused()
    }
    
    /// Resume the mock AR session
    public func resumeSession() {
        guard isSessionRunning else { return }
        startFrameGeneration()
        updateTrackingState(.normal)
        notifySessionResumed()
    }
    
    // MARK: - Mock Data Injection
    
    /// Inject mock ball detections for testing
    /// - Parameter detections: Array of ball detection results
    public func injectBallDetections(_ detections: [BallDetectionResult]) {
        mockDetections = detections
    }
    
    /// Add a single mock ball detection
    /// - Parameter detection: Ball detection result to add
    public func addMockDetection(_ detection: BallDetectionResult) {
        mockDetections.append(detection)
    }
    
    /// Clear all mock detections
    public func clearMockDetections() {
        mockDetections.removeAll()
    }
    
    /// Simulate tracking state change
    /// - Parameter newState: New tracking state to simulate
    public func simulateTrackingStateChange(_ newState: TrackingState) {
        updateTrackingState(newState)
    }
    
    /// Simulate camera movement
    /// - Parameters:
    ///   - position: New camera position in world space
    ///   - orientation: New camera orientation (quaternion)
    public func simulateCameraMovement(position: SIMD3<Float>, orientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) {
        let translation = matrix4x4_translation(position.x, position.y, position.z)
        let rotation = matrix4x4_rotation(orientation)
        cameraTransform = matrix_multiply(translation, rotation)
    }
    
    /// Simulate lighting condition change
    /// - Parameter intensity: Light intensity from 0.0 (dark) to 1.0 (bright)
    public func simulateLightingChange(_ intensity: Float) {
        lightingConditions = max(0.0, min(1.0, intensity))
        
        // Simulate tracking degradation in poor lighting
        if intensity < 0.3 {
            updateTrackingState(.limited(reason: .poorLighting))
        } else if trackingState == .limited(reason: .poorLighting) && intensity > 0.5 {
            updateTrackingState(.normal)
        }
    }
    
    // MARK: - Callback Management
    
    /// Add callback for session events
    /// - Parameter callback: Callback to add
    public func addSessionCallback(_ callback: @escaping MockARSessionCallback) {
        sessionCallbacks.append(callback)
    }
    
    /// Remove all session callbacks
    public func removeAllCallbacks() {
        sessionCallbacks.removeAll()
    }
    
    // MARK: - Test Utilities
    
    /// Get current performance metrics
    /// - Returns: Dictionary of performance metrics
    public func getPerformanceMetrics() -> [String: Double] {
        return performanceProfiler.getCurrentMetricsAsDictionary()
    }
    
    /// Get synthetic frame data for testing
    /// - Returns: Current mock frame data
    public func getCurrentMockFrame() -> MockARFrame {
        return frameProvider.generateFrame(
            timestamp: currentFrameTimestamp,
            cameraTransform: cameraTransform,
            lightingConditions: lightingConditions,
            detections: mockDetections
        )
    }
    
    /// Reset mock view to initial state
    public func reset() {
        if isSessionRunning {
            stopSession()
        }
        
        trackingState = .normal
        cameraTransform = matrix_identity_float4x4
        lightingConditions = 0.8
        currentFrameTimestamp = 0.0
        frameCounter = 0
        mockDetections.removeAll()
        sessionCallbacks.removeAll()
        performanceProfiler.reset()
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        trackingState = .notAvailable(reason: .cameraUnavailable)
        cameraTransform = matrix_identity_float4x4
        lightingConditions = 0.8
    }
    
    private func startFrameGeneration() {
        let frameInterval = 1.0 / Double(configuration.frameConfig.targetFrameRate)
        
        frameTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.generateFrame()
        }
    }
    
    private func stopFrameGeneration() {
        frameTimer?.invalidate()
        frameTimer = nil
    }
    
    private func generateFrame() {
        guard isSessionRunning else { return }
        
        frameCounter += 1
        
        if let startTime = sessionStartTime {
            currentFrameTimestamp = Date().timeIntervalSince(startTime)
        }
        
        // Update performance metrics
        performanceProfiler.recordFrameTime()
        
        // Apply configured motion simulation
        if configuration.enableMotionSimulation {
            simulateRealisticCameraMotion()
        }
        
        // Generate synthetic detections if enabled
        if configuration.enableSyntheticDetections {
            generateSyntheticDetections()
        }
        
        // Notify frame callbacks
        notifyFrameGenerated()
    }
    
    private func simulateRealisticCameraMotion() {
        let time = Float(currentFrameTimestamp)
        
        // Subtle camera shake simulation
        let shakeIntensity: Float = 0.001
        let shakeX = sin(time * 50.0) * shakeIntensity
        let shakeY = cos(time * 30.0) * shakeIntensity
        let shakeZ = sin(time * 40.0) * shakeIntensity * 0.5
        
        let currentPosition = SIMD3<Float>(
            cameraTransform.columns.3.x + shakeX,
            cameraTransform.columns.3.y + shakeY,
            cameraTransform.columns.3.z + shakeZ
        )
        
        simulateCameraMovement(position: currentPosition)
    }
    
    private func generateSyntheticDetections() {
        guard mockDetections.isEmpty else { return }
        
        // Generate 1-3 random ball detections
        let detectionCount = Int.random(in: configuration.syntheticDetectionRange)
        var newDetections: [BallDetectionResult] = []
        
        for _ in 0..<detectionCount {
            let position = SIMD3<Float>(
                Float.random(in: -2.0...2.0),
                Float.random(in: -1.0...1.0),
                Float.random(in: -5.0...5.0)
            )
            
            let confidence = Float.random(in: 0.7...0.95)
            let detection = BallDetectionResult(
                ballCenter3D: position,
                confidence: confidence,
                timestamp: currentFrameTimestamp
            )
            newDetections.append(detection)
        }
        
        mockDetections = newDetections
    }
    
    private func updateTrackingState(_ newState: TrackingState) {
        guard trackingState != newState else { return }
        let oldState = trackingState
        trackingState = newState
        notifyTrackingStateChanged(from: oldState, to: newState)
    }
    
    // MARK: - Notification Methods
    
    private func notifySessionStarted() {
        for callback in sessionCallbacks {
            callback(.sessionStarted)
        }
    }
    
    private func notifySessionStopped() {
        for callback in sessionCallbacks {
            callback(.sessionStopped)
        }
    }
    
    private func notifySessionPaused() {
        for callback in sessionCallbacks {
            callback(.sessionPaused)
        }
    }
    
    private func notifySessionResumed() {
        for callback in sessionCallbacks {
            callback(.sessionResumed)
        }
    }
    
    private func notifyTrackingStateChanged(from oldState: TrackingState, to newState: TrackingState) {
        for callback in sessionCallbacks {
            callback(.trackingStateChanged(from: oldState, to: newState))
        }
    }
    
    private func notifyFrameGenerated() {
        for callback in sessionCallbacks {
            callback(.frameGenerated(getCurrentMockFrame()))
        }
    }
}

// MARK: - Supporting Types

/// Configuration for MockARView behavior
public struct MockARConfiguration {
    /// Frame generation configuration
    public let frameConfig: ARFrameConfiguration
    
    /// Delay before session starts (simulates ARKit initialization)
    public let sessionStartDelay: TimeInterval
    
    /// Whether to simulate camera motion
    public let enableMotionSimulation: Bool
    
    /// Whether to generate synthetic ball detections
    public let enableSyntheticDetections: Bool
    
    /// Range for number of synthetic detections per frame
    public let syntheticDetectionRange: ClosedRange<Int>
    
    public init(
        frameConfig: ARFrameConfiguration = ARFrameConfiguration(),
        sessionStartDelay: TimeInterval = 0.1,
        enableMotionSimulation: Bool = true,
        enableSyntheticDetections: Bool = false,
        syntheticDetectionRange: ClosedRange<Int> = 0...2
    ) {
        self.frameConfig = frameConfig
        self.sessionStartDelay = sessionStartDelay
        self.enableMotionSimulation = enableMotionSimulation
        self.enableSyntheticDetections = enableSyntheticDetections
        self.syntheticDetectionRange = syntheticDetectionRange
    }
}

/// Session event callback type
public typealias MockARSessionCallback = (MockARSessionEvent) -> Void

/// Mock AR session events
public enum MockARSessionEvent {
    case sessionStarted
    case sessionStopped
    case sessionPaused
    case sessionResumed
    case trackingStateChanged(from: TrackingState, to: TrackingState)
    case frameGenerated(MockARFrame)
}

/// Mock AR frame data structure
public struct MockARFrame {
    public let timestamp: TimeInterval
    public let cameraTransform: matrix_float4x4
    public let lightingConditions: Float
    public let detections: [BallDetectionResult]
    public let frameNumber: UInt64
    
    public init(
        timestamp: TimeInterval,
        cameraTransform: matrix_float4x4,
        lightingConditions: Float,
        detections: [BallDetectionResult],
        frameNumber: UInt64
    ) {
        self.timestamp = timestamp
        self.cameraTransform = cameraTransform
        self.lightingConditions = lightingConditions
        self.detections = detections
        self.frameNumber = frameNumber
    }
}

// MARK: - Matrix Utilities

private func matrix4x4_translation(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
    return matrix_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(x, y, z, 1)
    )
}

private func matrix4x4_rotation(_ quaternion: simd_quatf) -> matrix_float4x4 {
    let x = quaternion.imag.x
    let y = quaternion.imag.y
    let z = quaternion.imag.z
    let w = quaternion.real
    
    return matrix_float4x4(
        SIMD4<Float>(1 - 2*y*y - 2*z*z, 2*x*y - 2*w*z, 2*x*z + 2*w*y, 0),
        SIMD4<Float>(2*x*y + 2*w*z, 1 - 2*x*x - 2*z*z, 2*y*z - 2*w*x, 0),
        SIMD4<Float>(2*x*z - 2*w*y, 2*y*z + 2*w*x, 1 - 2*x*x - 2*y*y, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}