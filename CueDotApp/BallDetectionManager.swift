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
    private var tableAnchorEntity: AnchorEntity? = nil
    private var tablePlaneEntity: ModelEntity? = nil
    private var showBoundingQuads: Bool = false // toggle for debug 2D bbox quads
    
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
            var pos = detection.worldPosition
            // Clamp ball height to table if tablePlaneEntity exists
            if let plane = tablePlaneEntity {
                let tableY = plane.position.y
                // place sphere center at table height + radius
                if let sphereChild = entity.children.first {
                    let radius = sphereChild.scale.x == 0 ? 0.05715/2.0 : (sphereChild.visualBounds(relativeTo: sphereChild).extents.x/2)
                    pos.y = tableY + radius
                } else {
                    pos.y = tableY + 0.05715/2.0
                }
            }
            entity.position = pos
            // Slight lift above table surface if y ~ 0 to avoid z-fighting
            if entity.position.y < 0.01 { entity.position.y += 0.01 }
            // Update existing label color if present
            if let label = entity.children.compactMap({ $0 as? ModelEntity }).first(where: { $0.name == "label" }) {
                let newColor = materialTextColor(detection)
                if var simple = label.model?.materials.first as? SimpleMaterial {
                    simple.color = .init(tint: newColor, texture: nil)
                    label.model?.materials = [simple]
                    // Add optional debug quad for 2D bbox projection
                    if showBoundingQuads, entity.children.first(where: { $0.name == "bbox" }) == nil {
                        if let quad = makeBoundingQuad(for: detection) {
                            entity.addChild(quad)
                        }
                    }
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

    // MARK: - Table Plane Handling
    private func updateTablePlane(with anchor: ARPlaneAnchor, in arView: ARView) {
        // We consider the first sufficiently large horizontal plane as table candidate
        guard anchor.alignment == .horizontal else { return }
        let extent = anchor.extent
        let minArea: Float = 0.5 // m^2 threshold for table candidate
        let area = extent.x * extent.z
        guard area >= minArea else { return }
        // Create or update plane entity
        let center = SIMD3<Float>(anchor.center.x, anchor.center.y, anchor.center.z)
        let tableHeight = center.y
        let confidence: Float = min(1.0, area / 2.5) // simple scaling up to area 2.5 m^2
        // Update integrator table info if available
        ballDetectionIntegrator?.updateTableInfo(center: center, height: tableHeight, normal: SIMD3<Float>(0,1,0), confidence: confidence)
        if tablePlaneEntity == nil {
            let mesh = MeshResource.generatePlane(width: CGFloat(extent.x), depth: CGFloat(extent.z))
            var material = SimpleMaterial(color: UIColor.systemTeal.withAlphaComponent(0.15), isMetallic: false)
            tablePlaneEntity = ModelEntity(mesh: mesh, materials: [material])
            tablePlaneEntity?.position = center
            if tableAnchorEntity == nil {
                tableAnchorEntity = AnchorEntity(world: center)
                arView.scene.addAnchor(tableAnchorEntity!)
            }
            tableAnchorEntity?.addChild(tablePlaneEntity!)
        } else {
            // Resize plane by replacing mesh
            let mesh = MeshResource.generatePlane(width: CGFloat(extent.x), depth: CGFloat(extent.z))
            tablePlaneEntity?.model?.mesh = mesh
            tablePlaneEntity?.position = center
        }
    }

    private func makeBoundingQuad(for detection: AR3DBallDetection) -> ModelEntity? {
        // Simple square facing camera sized relative to ball diameter
        let size: Float = max(0.05, detection.diameter)
        let mesh = MeshResource.generatePlane(width: CGFloat(size), depth: CGFloat(size))
        var material = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.15), isMetallic: false)
        let quad = ModelEntity(mesh: mesh, materials: [material])
        quad.name = "bbox"
        quad.position = [0, size * 0.6, 0] // float above ball center
        // Face camera each frame via billboard constraint (manual on update could be added later)
        return quad
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
        let maroon = UIColor(red: 128/255.0, green: 0/255.0, blue: 32/255.0, alpha: 1.0)
        let mapping: [Int: UIColor] = [
            0: .white, // cue
            1: .systemYellow,
            2: .systemBlue,
            3: .systemRed,
            4: .systemPurple,
            5: .systemOrange,
            6: .systemGreen,
            7: maroon,
            8: .black,
            9: .systemYellow,
            10: .systemBlue,
            11: .systemRed,
            12: .systemPurple,
            13: .systemOrange,
            14: .systemGreen,
            15: maroon
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

            func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
                guard let arView = arView else { return }
                for anchor in anchors {
                    if let plane = anchor as? ARPlaneAnchor { updateTablePlane(with: plane, in: arView) }
                }
            }

            func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
                guard let arView = arView else { return }
                for anchor in anchors {
                    if let plane = anchor as? ARPlaneAnchor { updateTablePlane(with: plane, in: arView) }
                }
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
