import Foundation
import simd
#if canImport(ARKit)
import ARKit
#endif
#if canImport(SceneKit)
import SceneKit
#endif

/// Camera transform manager for AR coordinate system integration
/// Handles camera pose, projection matrices, and viewport transformations
@available(iOS 13.0, *)
public class ARCameraTransform {
    
    // MARK: - Properties
    
    /// Current camera pose in world space
    public private(set) var cameraTransform: simd_float4x4
    
    /// Camera projection matrix for current frame
    public private(set) var projectionMatrix: simd_float4x4
    
    /// Camera intrinsic parameters
    public private(set) var intrinsics: simd_float3x3
    
    /// Current viewport size
    public private(set) var viewportSize: CGSize
    
    /// Camera tracking state
    public private(set) var trackingState: CameraTrackingState
    
    /// Camera tracking quality
    public private(set) var trackingQuality: CameraTrackingQuality
    
    /// Field of view information
    public private(set) var fieldOfView: CameraFieldOfView
    
    /// Near and far clipping planes
    public private(set) var nearClip: Float = 0.001
    public private(set) var farClip: Float = 1000.0
    
    /// Timestamp of last update
    public private(set) var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    /// Initialize with default camera parameters
    public init() {
        self.cameraTransform = matrix_identity_float4x4
        self.projectionMatrix = matrix_identity_float4x4
        self.intrinsics = matrix_identity_float3x3
        self.viewportSize = CGSize(width: 1920, height: 1080)
        self.trackingState = .notAvailable
        self.trackingQuality = .insufficient
        self.fieldOfView = CameraFieldOfView()
    }
    
    // MARK: - Frame Updates
    
    #if canImport(ARKit)
    /// Update camera transform from ARFrame
    /// - Parameter frame: Current ARFrame containing camera data
    public func updateFromARFrame(_ frame: ARFrame) {
        self.cameraTransform = frame.camera.transform
        self.intrinsics = frame.camera.intrinsics
        
        // Calculate projection matrix for landscape orientation
        let orientation: UIInterfaceOrientation = .landscapeRight
        let imageResolution = frame.camera.imageResolution
        self.viewportSize = CGSize(width: imageResolution.width, height: imageResolution.height)
        
        self.projectionMatrix = frame.camera.projectionMatrix(
            for: orientation,
            viewportSize: viewportSize,
            zNear: CGFloat(nearClip),
            zFar: CGFloat(farClip)
        )
        
        // Update tracking state
        updateTrackingState(frame.camera.trackingState)
        
        // Update field of view
        updateFieldOfView(from: frame.camera)
        
        self.lastUpdateTime = frame.timestamp
    }
    
    /// Update tracking state from ARCamera
    private func updateTrackingState(_ trackingState: ARCamera.TrackingState) {
        switch trackingState {
        case .normal:
            self.trackingState = .normal
            self.trackingQuality = .excellent
        case .limited(let reason):
            self.trackingState = .limited
            switch reason {
            case .excessiveMotion:
                self.trackingQuality = .poor
            case .insufficientFeatures:
                self.trackingQuality = .insufficient
            case .initializing:
                self.trackingQuality = .initializing
            case .relocalizing:
                self.trackingQuality = .poor
            @unknown default:
                self.trackingQuality = .insufficient
            }
        case .notAvailable:
            self.trackingState = .notAvailable
            self.trackingQuality = .insufficient
        }
    }
    
    /// Update field of view from ARCamera
    private func updateFieldOfView(from camera: ARCamera) {
        // Calculate field of view from projection matrix
        let projMatrix = projectionMatrix
        let fovY = 2.0 * atan(1.0 / projMatrix[1, 1])
        let aspectRatio = projMatrix[1, 1] / projMatrix[0, 0]
        let fovX = 2.0 * atan(tan(fovY * 0.5) * aspectRatio)
        
        self.fieldOfView = CameraFieldOfView(
            horizontalFOV: fovX,
            verticalFOV: fovY,
            aspectRatio: aspectRatio
        )
    }
    #endif
    
    /// Manually update camera parameters (for testing)
    /// - Parameters:
    ///   - transform: Camera transform matrix
    ///   - intrinsics: Camera intrinsic parameters
    ///   - viewportSize: Viewport dimensions
    ///   - projectionMatrix: Projection matrix
    public func updateManually(
        transform: simd_float4x4,
        intrinsics: simd_float3x3,
        viewportSize: CGSize,
        projectionMatrix: simd_float4x4
    ) {
        self.cameraTransform = transform
        self.intrinsics = intrinsics
        self.viewportSize = viewportSize
        self.projectionMatrix = projectionMatrix
        self.lastUpdateTime = ProcessInfo.processInfo.systemUptime
        self.trackingState = .normal
        self.trackingQuality = .excellent
    }
    
    // MARK: - Camera Properties
    
    /// Get current camera position in world space
    /// - Returns: 3D position vector
    public func getCameraPosition() -> simd_float3 {
        return simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
    }
    
    /// Get camera forward direction (where camera is pointing)
    /// - Returns: Normalized direction vector
    public func getCameraDirection() -> simd_float3 {
        // In ARKit, camera looks down negative Z axis
        return simd_normalize(-simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ))
    }
    
    /// Get camera up direction
    /// - Returns: Normalized up vector
    public func getCameraUp() -> simd_float3 {
        return simd_normalize(simd_float3(
            cameraTransform.columns.1.x,
            cameraTransform.columns.1.y,
            cameraTransform.columns.1.z
        ))
    }
    
    /// Get camera right direction
    /// - Returns: Normalized right vector
    public func getCameraRight() -> simd_float3 {
        return simd_normalize(simd_float3(
            cameraTransform.columns.0.x,
            cameraTransform.columns.0.y,
            cameraTransform.columns.0.z
        ))
    }
    
    /// Get camera rotation as quaternion
    /// - Returns: Rotation quaternion
    public func getCameraRotation() -> simd_quatf {
        let rotationMatrix = simd_float3x3(
            simd_float3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z),
            simd_float3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z),
            simd_float3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        )
        return simd_quatf(rotationMatrix)
    }
    
    // MARK: - Coordinate Transformations
    
    /// Transform point from world space to camera space
    /// - Parameter worldPoint: Point in world coordinates
    /// - Returns: Point in camera coordinates
    public func worldToCamera(_ worldPoint: simd_float3) -> simd_float3 {
        let worldHomogeneous = simd_float4(worldPoint.x, worldPoint.y, worldPoint.z, 1.0)
        let cameraHomogeneous = simd_inverse(cameraTransform) * worldHomogeneous
        return simd_float3(cameraHomogeneous.x, cameraHomogeneous.y, cameraHomogeneous.z)
    }
    
    /// Transform point from camera space to world space
    /// - Parameter cameraPoint: Point in camera coordinates
    /// - Returns: Point in world coordinates
    public func cameraToWorld(_ cameraPoint: simd_float3) -> simd_float3 {
        let cameraHomogeneous = simd_float4(cameraPoint.x, cameraPoint.y, cameraPoint.z, 1.0)
        let worldHomogeneous = cameraTransform * cameraHomogeneous
        return simd_float3(worldHomogeneous.x, worldHomogeneous.y, worldHomogeneous.z)
    }
    
    /// Project 3D point to screen coordinates
    /// - Parameter worldPoint: Point in world coordinates
    /// - Returns: Screen coordinates (x, y) or nil if behind camera
    public func worldToScreen(_ worldPoint: simd_float3) -> CGPoint? {
        let cameraPoint = worldToCamera(worldPoint)
        
        // Check if point is behind camera
        guard cameraPoint.z < 0 else { return nil }
        
        // Project using intrinsics
        let projectedPoint = intrinsics * cameraPoint
        
        // Perspective divide
        let normalizedX = projectedPoint.x / projectedPoint.z
        let normalizedY = projectedPoint.y / projectedPoint.z
        
        // Convert to screen coordinates
        let screenX = (normalizedX + 1.0) * 0.5 * Float(viewportSize.width)
        let screenY = (1.0 - normalizedY) * 0.5 * Float(viewportSize.height)
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    /// Create ray from screen coordinates
    /// - Parameter screenPoint: Screen coordinates
    /// - Returns: Ray origin and direction in world space
    public func screenToWorldRay(_ screenPoint: CGPoint) -> (origin: simd_float3, direction: simd_float3) {
        // Convert screen to normalized device coordinates
        let normalizedX = (Float(screenPoint.x) / Float(viewportSize.width)) * 2.0 - 1.0
        let normalizedY = 1.0 - (Float(screenPoint.y) / Float(viewportSize.height)) * 2.0
        
        // Transform to camera space
        let inverseIntrinsics = simd_inverse(intrinsics)
        let cameraSpacePoint = inverseIntrinsics * simd_float3(normalizedX, normalizedY, -1.0)
        
        // Ray origin is camera position
        let rayOrigin = getCameraPosition()
        
        // Transform direction to world space
        let cameraSpaceDirection = simd_normalize(cameraSpacePoint)
        let worldSpaceDirection = cameraToWorld(cameraSpaceDirection) - rayOrigin
        
        return (origin: rayOrigin, direction: simd_normalize(worldSpaceDirection))
    }
    
    // MARK: - Utility Methods
    
    /// Check if camera tracking is reliable
    /// - Returns: true if tracking is good enough for overlay rendering
    public func isTrackingReliable() -> Bool {
        return trackingState == .normal && trackingQuality.rawValue >= CameraTrackingQuality.good.rawValue
    }
    
    /// Get distance from camera to point
    /// - Parameter worldPoint: Point in world coordinates
    /// - Returns: Distance in meters
    public func distanceFromCamera(_ worldPoint: simd_float3) -> Float {
        let cameraPosition = getCameraPosition()
        return simd_distance(cameraPosition, worldPoint)
    }
    
    /// Check if point is within camera view frustum
    /// - Parameter worldPoint: Point to check
    /// - Returns: true if point is potentially visible
    public func isPointInViewFrustum(_ worldPoint: simd_float3) -> Bool {
        let cameraPoint = worldToCamera(worldPoint)
        
        // Check if behind camera
        guard cameraPoint.z < 0 else { return false }
        
        // Check if within field of view
        let distance = abs(cameraPoint.z)
        let maxX = tan(fieldOfView.horizontalFOV * 0.5) * distance
        let maxY = tan(fieldOfView.verticalFOV * 0.5) * distance
        
        return abs(cameraPoint.x) <= maxX && abs(cameraPoint.y) <= maxY
    }
    
    /// Calculate optimal overlay position avoiding screen edges
    /// - Parameters:
    ///   - worldPoint: 3D point for overlay
    ///   - overlaySize: Size of overlay element
    ///   - margin: Margin from screen edges
    /// - Returns: Adjusted screen position
    public func calculateSafeOverlayPosition(
        for worldPoint: simd_float3,
        overlaySize: CGSize,
        margin: CGFloat = 20
    ) -> CGPoint? {
        guard let screenPoint = worldToScreen(worldPoint) else { return nil }
        
        var adjustedPoint = screenPoint
        
        // Adjust for screen boundaries
        let minX = margin
        let maxX = viewportSize.width - overlaySize.width - margin
        let minY = margin
        let maxY = viewportSize.height - overlaySize.height - margin
        
        adjustedPoint.x = max(minX, min(maxX, adjustedPoint.x))
        adjustedPoint.y = max(minY, min(maxY, adjustedPoint.y))
        
        return adjustedPoint
    }
    
    #if canImport(SceneKit)
    /// Convert camera transform to SceneKit format
    /// - Returns: SCNMatrix4 for SceneKit camera
    public func toSceneKitTransform() -> SCNMatrix4 {
        return SCNMatrix4(cameraTransform)
    }
    
    /// Create SceneKit camera node with current parameters
    /// - Returns: Configured SCNNode with camera
    public func createSceneKitCameraNode() -> SCNNode {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        
        // Configure camera parameters
        camera.fieldOfView = CGFloat(fieldOfView.verticalFOV * 180.0 / .pi) // Convert to degrees
        camera.zNear = Double(nearClip)
        camera.zFar = Double(farClip)
        
        cameraNode.camera = camera
        cameraNode.transform = toSceneKitTransform()
        
        return cameraNode
    }
    #endif
}

// MARK: - Supporting Types

/// Camera tracking state
public enum CameraTrackingState {
    case notAvailable
    case limited
    case normal
}

/// Camera tracking quality levels
public enum CameraTrackingQuality: Int, CaseIterable {
    case insufficient = 0
    case initializing = 1
    case poor = 2
    case good = 3
    case excellent = 4
}

/// Field of view information
public struct CameraFieldOfView {
    /// Horizontal field of view in radians
    public let horizontalFOV: Float
    
    /// Vertical field of view in radians
    public let verticalFOV: Float
    
    /// Aspect ratio (width/height)
    public let aspectRatio: Float
    
    public init(horizontalFOV: Float = 1.0, verticalFOV: Float = 0.75, aspectRatio: Float = 16.0/9.0) {
        self.horizontalFOV = horizontalFOV
        self.verticalFOV = verticalFOV
        self.aspectRatio = aspectRatio
    }
}

// MARK: - Extensions

@available(iOS 13.0, *)
extension ARCameraTransform {
    
    /// Get diagnostic information for debugging
    /// - Returns: Dictionary containing camera state information
    public func getDiagnosticInfo() -> [String: Any] {
        let position = getCameraPosition()
        let direction = getCameraDirection()
        
        return [
            "camera_position": [position.x, position.y, position.z],
            "camera_direction": [direction.x, direction.y, direction.z],
            "tracking_state": trackingState,
            "tracking_quality": trackingQuality,
            "viewport_size": [viewportSize.width, viewportSize.height],
            "field_of_view": [fieldOfView.horizontalFOV, fieldOfView.verticalFOV],
            "last_update": lastUpdateTime,
            "is_reliable": isTrackingReliable()
        ]
    }
    
    /// Create view matrix for rendering
    /// - Returns: View matrix (inverse of camera transform)
    public func getViewMatrix() -> simd_float4x4 {
        return simd_inverse(cameraTransform)
    }
    
    /// Create projection matrix for rendering
    /// - Returns: 4x4 projection matrix
    public func getProjectionMatrix4x4() -> simd_float4x4 {
        // The projection matrix is already 4x4
        return projectionMatrix
    }
}