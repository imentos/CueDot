import Foundation
import ARKit
import RealityKit
import SwiftUI
import Combine
import CueDot

class BallDetectionManager: NSObject, ObservableObject {
    @Published var detectedBalls: [DetectedBall] = []
    @Published var isTracking: Bool = false
    @Published var isGuidanceEnabled: Bool = false
    
    private var arView: ARView?
    private var ballDetectionIntegrator: ARBallDetectionIntegrator?
    private var frameProcessingQueue = DispatchQueue(label: "com.cuedot.frameProcessing", qos: .userInitiated)
    
    struct DetectedBall: Identifiable {
        let id = UUID()
        let position: SIMD3<Float>
        let color: String
        let confidence: Float
    }
    
    func setupAR(with arView: ARView) {
        self.arView = arView
        
        // Set this manager as the AR session delegate
        arView.session.delegate = self
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arView.session.run(configuration)
        
        // Set up ball detection integrator
        setupBallDetection()
    }
    
    private func setupBallDetection() {
        // Initialize the ball detection integrator
        // Detection happens automatically when AR frames are received
        ballDetectionIntegrator = ARBallDetectionIntegrator()
        
        // Note: ARBallDetectionIntegrator processes frames via detectBallsIn3D(frame:completion:)
        // This should be called in the ARSessionDelegate's didUpdate frame method
        isTracking = true
    }
    
    func startSession() {
        guard let arView = arView else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arView.session.run(configuration)
        isTracking = true
        
        // Clear any previous detections
        detectedBalls.removeAll()
        
        // Ball detection continues automatically when AR frames are processed
        isTracking = ballDetectionIntegrator != nil
    }
    
    func stopSession() {
        arView?.session.pause()
        isTracking = false
    }
    
    func resetSession() {
        guard let arView = arView else { return }
        
        // Reset AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Reset detection
        ballDetectionIntegrator?.reset()
        detectedBalls.removeAll()
        
        // Ball detection will resume automatically when AR frames are processed
        isTracking = ballDetectionIntegrator != nil
    }
    
    func startCalibration() {
        // Start table calibration process
        print("Starting table calibration...")
        // This would trigger the table detection and calibration process
    }
    
    func toggleGuidance() {
        isGuidanceEnabled.toggle()
        print("Guidance \(isGuidanceEnabled ? "enabled" : "disabled")")
        // This would enable/disable the AR cue guidance overlay
    }
    
    // MARK: - Helper Methods
    
    private func processBallDetectionResult(_ result: ARBallDetectionResult) {
        // Convert AR3DBallDetection to our DetectedBall model
        let balls = result.detections3D.map { detection in
            DetectedBall(
                position: detection.worldPosition,
                color: ballColorToString(detection.colorResult),
                confidence: detection.confidence
            )
        }
        
        // Update on main thread
        DispatchQueue.main.async {
            self.detectedBalls = balls
        }
    }
    
    private func ballColorToString(_ colorResult: BallColorResult?) -> String {
        guard let colorResult = colorResult else {
            return "Unknown"
        }
        
        // Since internal properties are not accessible, we use a simplified approach
        // based on confidence and stripe detection
        if colorResult.hasStripes {
            return "Striped Ball"
        } else {
            return "Solid Ball"
        }
    }
}

// MARK: - ARSessionDelegate

extension BallDetectionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Only process if tracking is enabled and integrator exists
        guard isTracking, let integrator = ballDetectionIntegrator else { return }
        
        // Process frame on background queue to avoid blocking the AR session
        frameProcessingQueue.async { [weak self] in
            integrator.detectBallsIn3D(frame: frame) { result in
                self?.processBallDetectionResult(result)
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isTracking = false
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
        DispatchQueue.main.async {
            self.isTracking = false
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        // Restart tracking if integrator is available
        if ballDetectionIntegrator != nil {
            DispatchQueue.main.async {
                self.isTracking = true
            }
        }
    }
}
