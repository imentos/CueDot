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
    @Published var minimumOverlayConfidence: Float = 0.3
    @Published var averageProcessingTimeMs: Double = 0.0
    @Published var lastFrameProcessingTimeMs: Double = 0.0
    @Published var overlayCount: Int = 0
    
    private var arView: ARView?
    private var ballDetectionIntegrator: ARBallDetectionIntegrator?
    private var frameProcessingQueue = DispatchQueue(label: "com.cuedot.frameProcessing", qos: .userInitiated)
    private var isProcessingFrame = false
    private var ballEntities: [String: ModelEntity] = [:]
    private var overlayAnchor: AnchorEntity = AnchorEntity(world: .zero)
    
    struct DetectedBall: Identifiable {
        let id = UUID()
        let detectionId: String
        let position: SIMD3<Float>
        let color: String
        let confidence: Float
    }
    
    func setupAR(with arView: ARView) {
        self.arView = arView

        // Prepare a single anchor for ball overlays
        arView.scene.addAnchor(overlayAnchor)
        
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
        ballDetectionIntegrator = ARBallDetectionIntegrator()
        
        // Start the underlying detection system
        do {
            try ballDetectionIntegrator?.startDetection()
            isTracking = true
            print("✅ Ball detection started successfully")
        } catch {
            print("❌ Failed to start ball detection: \(error)")
            isTracking = false
        }
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
        
        // Clear any previous detections
        detectedBalls.removeAll()
        
        // Start ball detection
        do {
            try ballDetectionIntegrator?.startDetection()
            isTracking = true
            print("✅ Ball detection session started")
        } catch {
            print("❌ Failed to start detection session: \(error)")
            isTracking = false
        }
    }
    
    func stopSession() {
        ballDetectionIntegrator?.stopDetection()
        arView?.session.pause()
        isTracking = false
        print("⏸️ Ball detection session stopped")
    }
    
    func resetSession() {
        guard let arView = arView else { return }
        
        // Reset AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Reset detection state
        ballDetectionIntegrator?.reset()
        detectedBalls.removeAll()
        
        // Restart ball detection
        do {
            try ballDetectionIntegrator?.startDetection()
            isTracking = true
            print("🔄 Ball detection session reset and restarted")
        } catch {
            print("❌ Failed to restart detection after reset: \(error)")
            isTracking = false
        }
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
                detectionId: detection.id,
                position: detection.worldPosition,
                color: ballColorToString(detection.colorResult),
                confidence: detection.confidence
            )
        }
        // Update processing metrics
        let processingMs = result.processingTime * 1000.0
        lastFrameProcessingTimeMs = processingMs
        // Simple moving average over last 30 frames
        processingHistory.append(processingMs)
        if processingHistory.count > 30 { processingHistory.removeFirst() }
        averageProcessingTimeMs = processingHistory.reduce(0, +) / Double(processingHistory.count)
        
        // Update on main thread
        DispatchQueue.main.async {
            self.detectedBalls = balls
            if self.isGuidanceEnabled { // reuse guidance toggle to show/hide overlays
                self.updateBallOverlays(with: result.detections3D)
            } else {
                self.clearBallOverlays()
            }
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

    // MARK: - Overlay Management
    private func updateBallOverlays(with detections: [AR3DBallDetection]) {
        guard let arView else { return }
        // Filter by minimum confidence
        let filtered = detections.filter { $0.confidence >= minimumOverlayConfidence }
        let currentIds = Set(filtered.map { $0.id })
        // Remove entities no longer present
        for (id, entity) in ballEntities where !currentIds.contains(id) {
            entity.removeFromParent()
            ballEntities.removeValue(forKey: id)
        }
        // Update or create entities
        for detection in filtered {
            let entity: ModelEntity
            if let existing = ballEntities[detection.id] {
                entity = existing
            } else {
                // Sphere sized to standard ball diameter if available
                let radius: Float = detection.diameter > 0 ? detection.diameter / 2.0 : 0.05715/2.0
                let sphereMesh = MeshResource.generateSphere(radius: radius)
                let materialColor = colorForConfidence(detection)
                let sphereMaterial = SimpleMaterial(color: materialColor.withAlphaComponent(0.9), isMetallic: false)
                let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
                // Container entity to hold sphere + label
                entity = ModelEntity()
                entity.addChild(sphereEntity)
                // Add text label
                if let labelEntity = makeLabelEntity(for: detection) {
                    labelEntity.position = [0, radius * 1.4, 0]
                    entity.addChild(labelEntity)
                }
                ballEntities[detection.id] = entity
                overlayAnchor.addChild(entity)
            }
            entity.position = detection.worldPosition
            // Slight lift above table surface if y ~ 0 to avoid z-fighting
            if entity.position.y < 0.01 { entity.position.y += 0.01 }
            // Update existing label color if present
            if let label = entity.children.compactMap({ $0 as? ModelEntity }).first(where: { $0.name == "label" }) {
                let newColor = materialTextColor(detection)
                if var simple = label.model?.materials.first as? SimpleMaterial {
                    simple.color = .init(tint: newColor, texture: nil)
                    label.model?.materials = [simple]
                }
            }
        }
        // Optional: scale anchor to identity (ensure not transformed elsewhere)
        overlayAnchor.transform = .identity
        overlayCount = ballEntities.count
    }

    private func clearBallOverlays() {
        for (_, entity) in ballEntities { entity.removeFromParent() }
        ballEntities.removeAll()
        overlayCount = 0
    }

    // MARK: - Color & Label Helpers
    private func colorForConfidence(_ detection: AR3DBallDetection) -> UIColor {
        // Priority: ball number specific color palette (simplified) else gradient
        if let number = detection.ballNumber, let paletteColor = ballNumberColor(number) {
            return paletteColor
        }
        let c = detection.confidence
        switch c {
        case ..<0.4: return .systemRed
        case 0.4..<0.7: return .systemYellow
        default: return .systemGreen
        }
    }

    private func materialTextColor(_ detection: AR3DBallDetection) -> UIColor {
        return detection.confidence >= 0.7 ? .white : .black
    }

    private func ballNumberColor(_ number: Int) -> UIColor? {
        // Basic 1-15 pool ball palette approximation
        let mapping: [Int: UIColor] = [
            0: .white, // cue
            1: .systemYellow,
            2: .systemBlue,
            3: .systemRed,
            4: .systemPurple,
            5: .systemOrange,
            6: .systemGreen,
            7: .systemMaroon,
            8: .black,
            9: .systemYellow,
            10: .systemBlue,
            11: .systemRed,
            12: .systemPurple,
            13: .systemOrange,
            14: .systemGreen,
            15: .systemMaroon
        ]
        return mapping[number]
    }

    private func makeLabelEntity(for detection: AR3DBallDetection) -> ModelEntity? {
        let numberText = detection.ballNumber?.description ?? "?"
        let confPercent = Int((detection.confidence * 100).rounded())
        let text = "\(numberText) \(confPercent)%"
        let font = UIFont.systemFont(ofSize: 0.05, weight: .bold)
        let mesh = MeshResource.generateText(text, font: font, containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
        var material = SimpleMaterial(color: materialTextColor(detection).withAlphaComponent(0.95), isMetallic: false)
        let labelEntity = ModelEntity(mesh: mesh, materials: [material])
        labelEntity.name = "label"
        // Scale text down (RealityKit text size large by default)
        labelEntity.scale = [0.02, 0.02, 0.02]
        return labelEntity
    }

    // Store processing times for moving average
    private var processingHistory: [Double] = []
}

// MARK: - ARSessionDelegate

extension BallDetectionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Only process if tracking is enabled and integrator exists
        guard isTracking, let integrator = ballDetectionIntegrator else { return }
        
        // Throttle: skip if previous frame still processing
        if isProcessingFrame { return }
        isProcessingFrame = true
        
        let frameCopy = frame // Pass directly; integrator now decouples internally
        frameProcessingQueue.async { [weak self] in
            integrator.detectBallsIn3D(frame: frameCopy) { result in
                self?.processBallDetectionResult(result)
                self?.isProcessingFrame = false
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
