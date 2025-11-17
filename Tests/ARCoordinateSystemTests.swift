import XCTest
import simd
@testable import CueDot

#if canImport(ARKit)
import ARKit
#endif

/// Comprehensive tests for AR coordinate system integration
/// Tests coordinate transformations, camera transforms, and overlay rendering
final class ARCoordinateSystemTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var coordinateTransform: ARCoordinateTransform!
    var cameraTransform: ARCameraTransform!
    var overlayRenderer: AROverlayRenderer!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        coordinateTransform = ARCoordinateTransform()
        cameraTransform = ARCameraTransform()
        overlayRenderer = AROverlayRenderer()
    }
    
    override func tearDownWithError() throws {
        coordinateTransform = nil
        cameraTransform = nil
        overlayRenderer?.cleanup()
        overlayRenderer = nil
    }
    
    // MARK: - ARCoordinateTransform Tests
    
    func testCoordinateTransformInitialization() throws {
        XCTAssertEqual(coordinateTransform.getCameraPosition(), simd_float3(0, 0, 0))
        XCTAssertEqual(coordinateTransform.getCameraDirection(), simd_float3(0, 0, -1))
    }
    
    func testWorldToScreenTransformation() throws {
        // Setup test camera parameters
        let testTransform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        )
        
        let testIntrinsics = simd_float3x3(
            simd_float3(800, 0, 400),
            simd_float3(0, 800, 300),
            simd_float3(0, 0, 1)
        )
        
        coordinateTransform.updateMatrices(
            cameraTransform: testTransform,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            intrinsics: testIntrinsics
        )
        
        // Test point transformation
        let worldPoint = simd_float3(0, 0, -1) // 1 meter in front of camera
        let screenPoint = coordinateTransform.worldToScreen(worldPoint)
        
        XCTAssertNotNil(screenPoint)
        XCTAssertEqual(screenPoint?.x ?? 0, 400, accuracy: 1.0) // Center X
        XCTAssertEqual(screenPoint?.y ?? 0, 300, accuracy: 1.0) // Center Y
    }
    
    func testScreenToWorldRayTransformation() throws {
        // Setup test camera
        let testTransform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        )
        
        let testIntrinsics = simd_float3x3(
            simd_float3(800, 0, 400),
            simd_float3(0, 800, 300),
            simd_float3(0, 0, 1)
        )
        
        coordinateTransform.updateMatrices(
            cameraTransform: testTransform,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            intrinsics: testIntrinsics
        )
        
        // Test ray from screen center
        let screenCenter = CGPoint(x: 400, y: 300)
        let ray = coordinateTransform.screenToWorldRay(screenCenter)
        
        XCTAssertEqual(ray.origin, simd_float3(0, 0, 0), accuracy: 0.001)
        XCTAssertEqual(ray.direction.z, -1.0, accuracy: 0.01) // Forward direction
    }
    
    func testCoordinateSpaceConversions() throws {
        // Test world to camera and camera to world conversions
        let worldPoint = simd_float3(1, 2, 3)
        let cameraPoint = coordinateTransform.worldToCamera(worldPoint)
        let backToWorld = coordinateTransform.cameraToWorld(cameraPoint)
        
        XCTAssertEqual(worldPoint.x, backToWorld.x, accuracy: 0.001)
        XCTAssertEqual(worldPoint.y, backToWorld.y, accuracy: 0.001)
        XCTAssertEqual(worldPoint.z, backToWorld.z, accuracy: 0.001)
    }
    
    func testDistanceCalculation() throws {
        let testPoint = simd_float3(3, 4, 0) // 5 units from origin
        let distance = coordinateTransform.distanceFromCamera(testPoint)
        
        XCTAssertEqual(distance, 5.0, accuracy: 0.001)
    }
    
    func testVisibilityCheck() throws {
        // Setup camera with known parameters
        coordinateTransform.updateMatrices(
            cameraTransform: matrix_identity_float4x4,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            intrinsics: matrix_identity_float3x3
        )
        
        // Point in front of camera should be visible
        let frontPoint = simd_float3(0, 0, -1)
        XCTAssertTrue(coordinateTransform.isPositionVisible(frontPoint))
        
        // Point behind camera should not be visible
        let behindPoint = simd_float3(0, 0, 1)
        XCTAssertFalse(coordinateTransform.isPositionVisible(behindPoint))
    }
    
    func testBoundingBoxProjection() throws {
        // Test bounding box projection
        let boundingBox = [
            simd_float3(-0.5, -0.5, -1),
            simd_float3(0.5, -0.5, -1),
            simd_float3(0.5, 0.5, -1),
            simd_float3(-0.5, 0.5, -1)
        ]
        
        let projectedBox = coordinateTransform.projectBoundingBox(boundingBox)
        XCTAssertNotNil(projectedBox)
        XCTAssertTrue(projectedBox?.width ?? 0 > 0)
        XCTAssertTrue(projectedBox?.height ?? 0 > 0)
    }
    
    func testOverlayPositionCalculation() throws {
        coordinateTransform.updateMatrices(
            cameraTransform: matrix_identity_float4x4,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            intrinsics: simd_float3x3(
                simd_float3(400, 0, 400),
                simd_float3(0, 400, 300),
                simd_float3(0, 0, 1)
            )
        )
        
        let worldPoint = simd_float3(0, 0, -1)
        let overlaySize = CGSize(width: 50, height: 30)
        
        let overlayPosition = coordinateTransform.calculateOverlayPosition(
            for: worldPoint,
            overlaySize: overlaySize
        )
        
        XCTAssertNotNil(overlayPosition)
        XCTAssertTrue(overlayPosition!.x >= 10) // Should respect margin
        XCTAssertTrue(overlayPosition!.y >= 10)
    }
    
    // MARK: - ARCameraTransform Tests
    
    func testCameraTransformInitialization() throws {
        XCTAssertEqual(cameraTransform.getCameraPosition(), simd_float3(0, 0, 0))
        XCTAssertEqual(cameraTransform.getCameraDirection(), simd_float3(0, 0, -1))
        XCTAssertFalse(cameraTransform.isTrackingReliable())
    }
    
    func testCameraPropertyCalculations() throws {
        // Setup test camera transform
        let testTransform = simd_float4x4(
            simd_float4(1, 0, 0, 5),   // X translation = 5
            simd_float4(0, 1, 0, 10),  // Y translation = 10
            simd_float4(0, 0, 1, 15),  // Z translation = 15
            simd_float4(0, 0, 0, 1)
        )
        
        cameraTransform.updateManually(
            transform: testTransform,
            intrinsics: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            projectionMatrix: matrix_identity_float3x3
        )
        
        let position = cameraTransform.getCameraPosition()
        XCTAssertEqual(position.x, 5.0, accuracy: 0.001)
        XCTAssertEqual(position.y, 10.0, accuracy: 0.001)
        XCTAssertEqual(position.z, 15.0, accuracy: 0.001)
    }
    
    func testCameraSpaceTransformations() throws {
        let worldPoint = simd_float3(1, 2, 3)
        let cameraPoint = cameraTransform.worldToCamera(worldPoint)
        let backToWorld = cameraTransform.cameraToWorld(cameraPoint)
        
        XCTAssertEqual(worldPoint.x, backToWorld.x, accuracy: 0.001)
        XCTAssertEqual(worldPoint.y, backToWorld.y, accuracy: 0.001)
        XCTAssertEqual(worldPoint.z, backToWorld.z, accuracy: 0.001)
    }
    
    func testScreenProjection() throws {
        // Setup camera with known parameters
        let intrinsics = simd_float3x3(
            simd_float3(800, 0, 400),
            simd_float3(0, 800, 300),
            simd_float3(0, 0, 1)
        )
        
        cameraTransform.updateManually(
            transform: matrix_identity_float4x4,
            intrinsics: intrinsics,
            viewportSize: CGSize(width: 800, height: 600),
            projectionMatrix: matrix_identity_float3x3
        )
        
        // Test center point projection
        let centerPoint = simd_float3(0, 0, -1)
        let screenPoint = cameraTransform.worldToScreen(centerPoint)
        
        XCTAssertNotNil(screenPoint)
        XCTAssertEqual(screenPoint?.x ?? 0, 400, accuracy: 1.0)
        XCTAssertEqual(screenPoint?.y ?? 0, 300, accuracy: 1.0)
    }
    
    func testViewFrustumCheck() throws {
        cameraTransform.updateManually(
            transform: matrix_identity_float4x4,
            intrinsics: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            projectionMatrix: matrix_identity_float3x3
        )
        
        // Point in front should be in frustum
        let frontPoint = simd_float3(0, 0, -1)
        XCTAssertTrue(cameraTransform.isPointInViewFrustum(frontPoint))
        
        // Point behind should not be in frustum
        let behindPoint = simd_float3(0, 0, 1)
        XCTAssertFalse(cameraTransform.isPointInViewFrustum(behindPoint))
    }
    
    func testCameraDistanceCalculation() throws {
        let testPoint = simd_float3(3, 4, 0)
        let distance = cameraTransform.distanceFromCamera(testPoint)
        
        XCTAssertEqual(distance, 5.0, accuracy: 0.001)
    }
    
    func testSafeOverlayPositioning() throws {
        cameraTransform.updateManually(
            transform: matrix_identity_float4x4,
            intrinsics: simd_float3x3(
                simd_float3(400, 0, 400),
                simd_float3(0, 400, 300),
                simd_float3(0, 0, 1)
            ),
            viewportSize: CGSize(width: 800, height: 600),
            projectionMatrix: matrix_identity_float3x3
        )
        
        let worldPoint = simd_float3(0, 0, -1)
        let overlaySize = CGSize(width: 50, height: 30)
        
        let safePosition = cameraTransform.calculateSafeOverlayPosition(
            for: worldPoint,
            overlaySize: overlaySize,
            margin: 20
        )
        
        XCTAssertNotNil(safePosition)
        XCTAssertTrue(safePosition!.x >= 20)
        XCTAssertTrue(safePosition!.y >= 20)
        XCTAssertTrue(safePosition!.x <= 800 - 50 - 20)
        XCTAssertTrue(safePosition!.y <= 600 - 30 - 20)
    }
    
    func testCameraDiagnosticInfo() throws {
        let diagnostics = cameraTransform.getDiagnosticInfo()
        
        XCTAssertNotNil(diagnostics["camera_position"])
        XCTAssertNotNil(diagnostics["camera_direction"])
        XCTAssertNotNil(diagnostics["tracking_state"])
        XCTAssertNotNil(diagnostics["tracking_quality"])
        XCTAssertNotNil(diagnostics["is_reliable"])
    }
    
    // MARK: - AROverlayRenderer Tests
    
    func testOverlayRendererInitialization() throws {
        XCTAssertNotNil(overlayRenderer)
        XCTAssertFalse(overlayRenderer.isActive)
        XCTAssertEqual(overlayRenderer.renderingMode, .realTime)
    }
    
    func testRendererConfiguration() throws {
        let config = ARRendererConfiguration()
        overlayRenderer.configuration = config
        
        XCTAssertEqual(overlayRenderer.configuration.ballVisuals.showOutlines, config.ballVisuals.showOutlines)
    }
    
    func testRendererPerformanceMetrics() throws {
        let metrics = overlayRenderer.getPerformanceMetrics()
        XCTAssertTrue(metrics.isEmpty) // Should be empty initially
    }
    
    func testOverlayOpacityControl() throws {
        overlayRenderer.setOverlayOpacity(0.5)
        // Should not crash - implementation specific behavior
    }
    
    func testQualityLevelControl() throws {
        overlayRenderer.setQualityLevel(0.8)
        // Should not crash and clamp value properly
        
        overlayRenderer.setQualityLevel(-0.5) // Should clamp to 0
        overlayRenderer.setQualityLevel(1.5)  // Should clamp to 1
    }
    
    func testLayerVisibilityControl() throws {
        let layers: [RenderLayer: Bool] = [
            .balls: true,
            .trajectories: false,
            .cueGuidance: true,
            .table: false
        ]
        
        overlayRenderer.setLayerVisibility(layers)
        
        let metrics = overlayRenderer.getPerformanceMetrics()
        XCTAssertEqual(metrics["layer_balls_visible"], 1.0)
        XCTAssertEqual(metrics["layer_trajectories_visible"], 0.0)
    }
    
    func testRendererLifecycle() throws {
        // Test pause/resume cycle
        overlayRenderer.pause()
        XCTAssertFalse(overlayRenderer.isActive)
        
        overlayRenderer.resume()
        XCTAssertTrue(overlayRenderer.isActive)
        
        // Test cleanup
        overlayRenderer.cleanup()
        XCTAssertFalse(overlayRenderer.isActive)
    }
    
    // MARK: - Integration Tests
    
    func testCoordinateSystemIntegration() throws {
        // Test that all components work together
        let worldPoint = simd_float3(1, 0, -2)
        
        // Setup coordinate transform
        coordinateTransform.updateMatrices(
            cameraTransform: matrix_identity_float4x4,
            projectionMatrix: matrix_identity_float3x3,
            viewportSize: CGSize(width: 800, height: 600),
            intrinsics: simd_float3x3(
                simd_float3(400, 0, 400),
                simd_float3(0, 400, 300),
                simd_float3(0, 0, 1)
            )
        )
        
        // Setup camera transform with same parameters
        cameraTransform.updateManually(
            transform: matrix_identity_float4x4,
            intrinsics: simd_float3x3(
                simd_float3(400, 0, 400),
                simd_float3(0, 400, 300),
                simd_float3(0, 0, 1)
            ),
            viewportSize: CGSize(width: 800, height: 600),
            projectionMatrix: matrix_identity_float3x3
        )
        
        // Test both transforms give same results
        let screenPoint1 = coordinateTransform.worldToScreen(worldPoint)
        let screenPoint2 = cameraTransform.worldToScreen(worldPoint)
        
        XCTAssertNotNil(screenPoint1)
        XCTAssertNotNil(screenPoint2)
        
        // Should give similar results (allowing for small differences due to implementation)
        XCTAssertEqual(screenPoint1?.x ?? 0, screenPoint2?.x ?? 0, accuracy: 10.0)
        XCTAssertEqual(screenPoint1?.y ?? 0, screenPoint2?.y ?? 0, accuracy: 10.0)
    }
    
    func testMockBallRenderingPipeline() throws {
        // Create mock tracked balls
        let mockBalls = createMockTrackedBalls()
        
        // Test that rendering doesn't crash with mock data
        let testTransform = matrix_identity_float4x4
        let mockARView = PlatformARView()
        
        XCTAssertNoThrow(
            try overlayRenderer.renderBalls(mockBalls, in: mockARView, cameraTransform: testTransform)
        )
        
        let metrics = overlayRenderer.getPerformanceMetrics()
        XCTAssertEqual(metrics["ball_count"], Double(mockBalls.count))
    }
    
    func testMockTrajectoryRendering() throws {
        let mockTrajectories = createMockTrajectories()
        let mockARView = MockARView()
        
        XCTAssertNoThrow(
            try overlayRenderer.renderTrajectories(mockTrajectories, in: mockARView, showProbability: true)
        )
    }
    
    // MARK: - Performance Tests
    
    func testCoordinateTransformPerformance() throws {
        let worldPoints = (0..<1000).map { i in
            simd_float3(Float(i), Float(i * 2), Float(-i))
        }
        
        measure {
            for point in worldPoints {
                _ = coordinateTransform.worldToScreen(point)
            }
        }
    }
    
    func testCameraTransformPerformance() throws {
        let worldPoints = (0..<1000).map { i in
            simd_float3(Float(i), Float(i * 2), Float(-i))
        }
        
        measure {
            for point in worldPoints {
                _ = cameraTransform.worldToCamera(point)
                _ = cameraTransform.distanceFromCamera(point)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockTrackedBalls() -> [TrackedBall] {
        return [
            TrackedBall(
                position: simd_float3(0, 0, -1),
                confidence: 0.95,
                lastDetectionTime: ProcessInfo.processInfo.systemUptime
            ),
            TrackedBall(
                position: simd_float3(0.5, 0, -1.5),
                confidence: 0.87,
                lastDetectionTime: ProcessInfo.processInfo.systemUptime
            ),
            TrackedBall(
                position: simd_float3(-0.5, 0.3, -2),
                confidence: 0.76,
                lastDetectionTime: ProcessInfo.processInfo.systemUptime
            )
        ]
    }
    
    private func createMockTrajectories() -> [UUID: [TrajectoryPoint]] {
        let ballId = UUID()
        let trajectoryPoints = (0..<10).map { i in
            TrajectoryPoint(
                position: simd_float3(Float(i) * 0.1, 0, Float(-i) * 0.1),
                velocity: simd_float3(1, 0, -1),
                timeOffset: TimeInterval(i) * 0.1,
                confidence: 0.9 - Double(i) * 0.05
            )
        }
        
        return [ballId: trajectoryPoints]
    }
}

// MARK: - Mock ARView for Testing

class MockARView: PlatformARView {
    override init() {
        super.init()
    }
}

// MARK: - Test Extensions

extension simd_float3 {
    func isEqual(to other: simd_float3, accuracy: Float) -> Bool {
        return abs(self.x - other.x) < accuracy &&
               abs(self.y - other.y) < accuracy &&
               abs(self.z - other.z) < accuracy
    }
}

extension XCTAssertEqual where T == simd_float3 {
    static func XCTAssertEqual(_ expression1: simd_float3, _ expression2: simd_float3, accuracy: Float, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(expression1.isEqual(to: expression2, accuracy: accuracy), "Values not equal within accuracy", file: file, line: line)
    }
}