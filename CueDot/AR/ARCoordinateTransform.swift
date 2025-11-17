import Foundation
import simd
#if canImport(ARKit)
import ARKit
#endif
#if canImport(SceneKit)
import SceneKit
#endif

/// Core coordinate transformation utilities for ARKit integration
/// Handles conversions between camera space, world space, and screen space coordinates
@available(iOS 13.0, *)
public class ARCoordinateTransform {
    
    // MARK: - Properties
    
    /// Current camera transform matrix (camera to world space)
    private(set) var cameraTransform: simd_float4x4
    
    /// Current projection matrix for camera
    private(set) var projectionMatrix: simd_float4x4
    
    /// Viewport dimensions in pixels
    private(set) var viewportSize: CGSize
    
    /// Camera intrinsic parameters for accurate transformations
    private(set) var intrinsics: simd_float3x3
    
    // MARK: - Initialization
    
    /// Initialize coordinate transform with default identity matrices
    public init() {
        self.cameraTransform = matrix_identity_float4x4
        self.projectionMatrix = matrix_identity_float4x4
        self.viewportSize = CGSize(width: 1920, height: 1080) // Default iPhone camera resolution
        self.intrinsics = matrix_identity_float3x3
    }
    
    // MARK: - Matrix Updates
    
    #if canImport(ARKit) && os(iOS)
    /// Update transformation matrices from ARFrame
    /// - Parameter frame: Current ARFrame containing camera data
    public func updateFromARFrame(_ frame: ARFrame) {
        self.cameraTransform = frame.camera.transform
        self.projectionMatrix = frame.camera.projectionMatrix(for: .landscapeRight, viewportSize: viewportSize, zNear: 0.001, zFar: 1000.0)
        self.intrinsics = frame.camera.intrinsics
        
        // Update viewport size from frame if available
        let imageResolution = frame.camera.imageResolution
        self.viewportSize = CGSize(width: imageResolution.width, height: imageResolution.height)
    }
    #endif
    
    /// Manually update transformation matrices (for testing)
    /// - Parameters:
    ///   - cameraTransform: Camera transform matrix
    ///   - projectionMatrix: Projection matrix
    ///   - viewportSize: Viewport dimensions
    ///   - intrinsics: Camera intrinsic parameters
    public func updateMatrices(
        cameraTransform: simd_float4x4,
        projectionMatrix: simd_float4x4,
        viewportSize: CGSize,
        intrinsics: simd_float3x3
    ) {
        self.cameraTransform = cameraTransform
        self.projectionMatrix = projectionMatrix
        self.viewportSize = viewportSize
        self.intrinsics = intrinsics
    }
    
    // MARK: - Coordinate Conversions
    
    /// Convert world space coordinates to screen space
    /// - Parameter worldPosition: 3D position in world coordinates
    /// - Returns: 2D screen coordinates, or nil if point is behind camera
    public func worldToScreen(_ worldPosition: SIMD3<Float>) -> CGPoint? {
        let worldHomogeneous = SIMD4<Float>(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        
        // Transform to camera space
        let cameraSpacePosition = simd_inverse(cameraTransform) * worldHomogeneous
        
        // Check if point is behind camera (negative Z in camera space)
        guard cameraSpacePosition.z < 0 else { return nil }
        
        // Project to normalized device coordinates
        let cameraSpacePoint = SIMD3<Float>(cameraSpacePosition.x, cameraSpacePosition.y, cameraSpacePosition.z)
        let projectedPoint = intrinsics * cameraSpacePoint
        
        // Perspective divide
        let normalizedX = projectedPoint.x / projectedPoint.z
        let normalizedY = projectedPoint.y / projectedPoint.z
        
        // Convert to screen coordinates
        let screenX = (normalizedX + 1.0) * 0.5 * Float(viewportSize.width)
        let screenY = (1.0 - normalizedY) * 0.5 * Float(viewportSize.height) // Flip Y for screen coordinates
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    /// Convert screen coordinates to a ray in world space
    /// - Parameter screenPoint: 2D screen coordinates
    /// - Returns: Ray origin and direction in world space
    public func screenToWorldRay(_ screenPoint: CGPoint) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        // Convert screen coordinates to normalized device coordinates
        let normalizedX = (Float(screenPoint.x) / Float(viewportSize.width)) * 2.0 - 1.0
        let normalizedY = 1.0 - (Float(screenPoint.y) / Float(viewportSize.height)) * 2.0
        
        // Transform to camera space
        let inverseIntrinsics = simd_inverse(intrinsics)
        let cameraSpacePoint = inverseIntrinsics * SIMD3<Float>(normalizedX, normalizedY, -1.0)
        
        // Transform to world space
        let rayOrigin = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let cameraSpaceDirection = simd_normalize(cameraSpacePoint)
        let worldSpaceDirection = simd_normalize(SIMD3<Float>(
            cameraTransform.columns.0.x * cameraSpaceDirection.x + cameraTransform.columns.1.x * cameraSpaceDirection.y + cameraTransform.columns.2.x * cameraSpaceDirection.z,
            cameraTransform.columns.0.y * cameraSpaceDirection.x + cameraTransform.columns.1.y * cameraSpaceDirection.y + cameraTransform.columns.2.y * cameraSpaceDirection.z,
            cameraTransform.columns.0.z * cameraSpaceDirection.x + cameraTransform.columns.1.z * cameraSpaceDirection.y + cameraTransform.columns.2.z * cameraSpaceDirection.z
        ))
        
        return (origin: rayOrigin, direction: worldSpaceDirection)
    }
    
    /// Convert camera space coordinates to world space
    /// - Parameter cameraPosition: 3D position in camera coordinates
    /// - Returns: 3D position in world coordinates
    public func cameraToWorld(_ cameraPosition: SIMD3<Float>) -> SIMD3<Float> {
        let cameraHomogeneous = SIMD4<Float>(cameraPosition.x, cameraPosition.y, cameraPosition.z, 1.0)
        let worldHomogeneous = cameraTransform * cameraHomogeneous
        return SIMD3<Float>(worldHomogeneous.x, worldHomogeneous.y, worldHomogeneous.z)
    }
    
    /// Convert world space coordinates to camera space
    /// - Parameter worldPosition: 3D position in world coordinates
    /// - Returns: 3D position in camera coordinates
    public func worldToCamera(_ worldPosition: SIMD3<Float>) -> SIMD3<Float> {
        let worldHomogeneous = SIMD4<Float>(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        let cameraHomogeneous = simd_inverse(cameraTransform) * worldHomogeneous
        return SIMD3<Float>(cameraHomogeneous.x, cameraHomogeneous.y, cameraHomogeneous.z)
    }
    
    // MARK: - Utility Methods
    
    /// Calculate distance from camera to world point
    /// - Parameter worldPosition: 3D position in world coordinates
    /// - Returns: Distance in meters
    public func distanceFromCamera(_ worldPosition: SIMD3<Float>) -> Float {
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        return simd_distance(cameraPosition, worldPosition)
    }
    
    /// Check if a world position is visible in the current camera view
    /// - Parameters:
    ///   - worldPosition: 3D position to check
    ///   - margin: Additional margin around screen bounds (in pixels)
    /// - Returns: true if position is visible
    public func isPositionVisible(_ worldPosition: SIMD3<Float>, margin: CGFloat = 50) -> Bool {
        guard let screenPoint = worldToScreen(worldPosition) else {
            return false // Behind camera
        }
        
        return screenPoint.x >= -margin &&
               screenPoint.x <= viewportSize.width + margin &&
               screenPoint.y >= -margin &&
               screenPoint.y <= viewportSize.height + margin
    }
    
    /// Get current camera position in world space
    /// - Returns: Camera position as 3D vector
    public func getCameraPosition() -> SIMD3<Float> {
        return SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
    }
    
    /// Get current camera orientation in world space
    /// - Returns: Camera forward direction vector
    public func getCameraDirection() -> SIMD3<Float> {
        // In ARKit, camera looks down negative Z axis
        return -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
    }
    
    // MARK: - Advanced Transformations
    
    /// Project a 3D bounding box to screen space
    /// - Parameter boundingBox: 3D bounding box corners in world space
    /// - Returns: 2D screen space bounding rectangle, or nil if entirely behind camera
    public func projectBoundingBox(_ boundingBox: [SIMD3<Float>]) -> CGRect? {
        var projectedPoints: [CGPoint] = []
        
        for corner in boundingBox {
            if let screenPoint = worldToScreen(corner) {
                projectedPoints.append(screenPoint)
            }
        }
        
        // Need at least some points to create a bounding box
        guard !projectedPoints.isEmpty else { return nil }
        
        let minX = projectedPoints.map { $0.x }.min() ?? 0
        let maxX = projectedPoints.map { $0.x }.max() ?? 0
        let minY = projectedPoints.map { $0.y }.min() ?? 0
        let maxY = projectedPoints.map { $0.y }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Calculate optimal overlay position for a world point
    /// Adjusts position to avoid screen edges and occlusion
    /// - Parameters:
    ///   - worldPosition: 3D position for overlay
    ///   - overlaySize: Size of overlay in screen space
    ///   - offset: Additional offset in screen space
    /// - Returns: Optimal screen position for overlay
    public func calculateOverlayPosition(
        for worldPosition: SIMD3<Float>,
        overlaySize: CGSize,
        offset: CGPoint = CGPoint.zero
    ) -> CGPoint? {
        guard let basePosition = worldToScreen(worldPosition) else { return nil }
        
        var adjustedPosition = CGPoint(
            x: basePosition.x + offset.x,
            y: basePosition.y + offset.y
        )
        
        // Adjust to keep overlay on screen
        let margin: CGFloat = 10
        adjustedPosition.x = max(margin, min(viewportSize.width - overlaySize.width - margin, adjustedPosition.x))
        adjustedPosition.y = max(margin, min(viewportSize.height - overlaySize.height - margin, adjustedPosition.y))
        
        return adjustedPosition
    }
}

// MARK: - Extension for SceneKit Integration

#if canImport(SceneKit)
@available(iOS 13.0, *)
extension ARCoordinateTransform {
    
    /// Convert to SceneKit camera node transform
    /// - Returns: SCNMatrix4 for SceneKit camera positioning
    public func toSceneKitTransform() -> SCNMatrix4 {
        return SCNMatrix4(cameraTransform)
    }
    
    /// Update from SceneKit camera node
    /// - Parameter cameraNode: SceneKit camera node
    public func updateFromSceneKitCamera(_ cameraNode: SCNNode) {
        self.cameraTransform = simd_float4x4(cameraNode.transform)
    }
}
#endif