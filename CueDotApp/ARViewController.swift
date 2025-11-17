import UIKit
import ARKit
import RealityKit

class ARViewController: UIViewController {
    
    var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize ARView
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Configure AR session
        setupARSession()
        
        // Set up gestures
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    private func setupARSession() {
        arView.session.delegate = self
        
        // Add some basic lighting
        arView.environment.lighting.intensityExponent = 1.0
        // Note: Using default lighting instead of the deprecated fromProbe API
        // arView.environment.lighting.resource = try? .generate(fromEquirectangular: <#CGImage#>)
    }
    
    // Add gesture recognizers for interaction
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        // Perform hit testing
        let results = arView.hitTest(location, types: .existingPlane)
        
        if let result = results.first {
            // Handle tap on detected plane
            print("Tapped on plane at: \(result.worldTransform)")
        }
    }
}

// MARK: - ARSessionDelegate
extension ARViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process each frame for ball detection
        // This would be integrated with the CueDot detection system
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("Added \(anchors.count) anchors")
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Update anchors as needed
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        print("Removed \(anchors.count) anchors")
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        
        // Restart session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}