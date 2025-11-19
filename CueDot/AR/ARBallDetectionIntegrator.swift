import Foundation
import Vision
import simd
import CoreGraphics
#if canImport(ARKit)
import ARKit
#endif

/// Integrates enhanced ball detection with AR coordinate system
/// Provides 3D positioning of detected balls in world space coordinates
@available(iOS 14.0, *)
public class ARBallDetectionIntegrator {
    
    // MARK: - Core Components
    
    /// Enhanced vision detector for advanced ball detection
    private let enhancedDetector: EnhancedVisionBallDetector
    
    /// AR coordinate transformation utilities
    private let coordinateTransform: ARCoordinateTransform
    
    /// Camera transform for depth calculations
    private let cameraTransform: ARCameraTransform
    
    /// Temporal filtering for consistent tracking
    private let temporalFilter: TemporalFilterManager
    
    // MARK: - Configuration
    
    /// Known pool ball diameter in meters (standard 57.15mm)
    private let standardBallDiameter: Float = 0.05715
    
    /// Pool table detection settings
    private var tableHeight: Float = 0.0 // Detected table height
    private var tableCenter: simd_float3? = nil
    private var tableNormal: simd_float3 = simd_float3(0, 1, 0) // Assume horizontal table
    
    // MARK: - State Management
    
    /// Detected balls with 3D positions
    private var detectedBalls: [AR3DBallDetection] = []
    
    /// Table detection confidence
    private var tableDetectionConfidence: Float = 0.0
    
    /// Performance metrics
    private var performanceTracker = ARPerformanceTracker()
    
    // MARK: - Initialization
    
    public init() {
        self.enhancedDetector = EnhancedVisionBallDetector()
        self.coordinateTransform = ARCoordinateTransform()
        self.cameraTransform = ARCameraTransform()
        self.temporalFilter = TemporalFilterManager()
    }
    
    // MARK: - Main Detection Interface
    
    #if canImport(ARKit) && os(iOS)
    /// Detect balls in AR frame and provide 3D positions
    public func detectBallsIn3D(
        frame: ARFrame,
        completion: @escaping (ARBallDetectionResult) -> Void
    ) {
        let startTime = Date()
        
        // Update coordinate systems
        updateCoordinateSystems(frame)
        
        // Perform enhanced 2D detection
        enhancedDetector.detectBallsAsync(
            in: frame.capturedImage,
            cameraTransform: frame.camera.transform,
            timestamp: frame.timestamp
        ) { [weak self] result in
            
            guard let self = self else { return }
            
            switch result {
            case .success(let detections):
                // Convert 2D detections to 3D world positions
                let arResult = self.convert2DTo3D(
                    detections: detections,
                    cameraTransform: frame.camera.transform,
                    intrinsics: frame.camera.intrinsics,
                    timestamp: frame.timestamp
                )
                
                // Update performance tracking
                let processingTime = Date().timeIntervalSince(startTime)
                self.performanceTracker.updateProcessingTime(processingTime)
                
                completion(arResult)
                
            case .failure(let error):
                // Handle detection error
                print("Enhanced ball detection failed: \(error)")
                let emptyResult = ARBallDetectionResult(
                    detections3D: [],
                    processingTime: Date().timeIntervalSince(startTime),
                    frameTimestamp: frame.timestamp,
                    cameraTransform: frame.camera.transform,
                    tableInfo: getCurrentTableInfo(),
                    performanceMetrics: getPerformanceMetrics()
                )
                completion(emptyResult)
            }
        }
    }
    #endif
    
    /// Detect balls with manual coordinate system setup (for testing)
    public func detectBallsWithManualAR(
        pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        timestamp: TimeInterval,
        completion: @escaping (ARBallDetectionResult) -> Void
    ) {
        let startTime = Date()
        
        // Update coordinate systems manually
        coordinateTransform.updateMatrices(
            cameraTransform: cameraTransform,
            projectionMatrix: matrix_identity_float4x4, // Simplified for testing
            viewportSize: imageSize,
            intrinsics: intrinsics
        )
        
        self.cameraTransform.updateManually(
            transform: cameraTransform,
            intrinsics: intrinsics,
            viewportSize: imageSize,
            projectionMatrix: matrix_identity_float4x4
        )
        
        // Perform enhanced 2D detection
        enhancedDetector.detectBallsAsync(
            in: pixelBuffer,
            cameraTransform: cameraTransform,
            timestamp: timestamp
        ) { [weak self] result in
            
            guard let self = self else { return }
            
            switch result {
            case .success(let detections):
                // Convert 2D detections to 3D world positions
                let arResult = self.convert2DTo3D(
                    detections: detections,
                    cameraTransform: cameraTransform,
                    intrinsics: intrinsics,
                    timestamp: timestamp
                )
                
                // Update performance tracking
                let processingTime = Date().timeIntervalSince(startTime)
                self.performanceTracker.updateProcessingTime(processingTime)
                
                completion(arResult)
                
            case .failure(let error):
                // Handle detection error
                print("Enhanced ball detection failed: \(error)")
                let emptyResult = ARBallDetectionResult(
                    detections3D: [],
                    processingTime: Date().timeIntervalSince(startTime),
                    frameTimestamp: timestamp,
                    cameraTransform: cameraTransform,
                    tableInfo: getCurrentTableInfo(),
                    performanceMetrics: getPerformanceMetrics()
                )
                completion(emptyResult)
            }
        }
    }
    
    // MARK: - Coordinate System Updates
    
    #if canImport(ARKit) && os(iOS)
    private func updateCoordinateSystems(_ frame: ARFrame) {
        coordinateTransform.updateFromARFrame(frame)
        cameraTransform.updateFromARFrame(frame)
        
        // Update table detection if available
        detectPoolTable(in: frame)
    }
    #endif
    
    // MARK: - 2D to 3D Conversion
    
    #if canImport(ARKit) && os(iOS)
    #endif
    
    private func convertBallDetectionTo3D(
        detection: BallDetectionResult,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        timestamp: TimeInterval
    ) -> AR3DBallDetection {
        
        // Create AR3DBallDetection from BallDetectionResult
        // The BallDetectionResult already contains 3D position
        return AR3DBallDetection(
            id: UUID().uuidString,
            trackId: 0, // No tracking ID available from single detection
            boundingBox2D: CGRect.zero, // No 2D bounding box from 3D result
            worldPosition: detection.ballCenter3D,
            confidence: detection.confidence,
            diameter: 0.057, // Standard ball diameter in meters
            colorResult: nil, // No color analysis in this context
            velocity3D: simd_float3(0, 0, 0), // No velocity from single detection
            timestamp: detection.timestamp,
            rayOrigin: cameraTransform.columns.3.xyz,
            rayDirection: simd_normalize(detection.ballCenter3D - cameraTransform.columns.3.xyz),
            estimatedDepth: simd_length(detection.ballCenter3D - cameraTransform.columns.3.xyz),
            depthConfidence: detection.confidence
        )
    }
    
    private func convert2DTo3D(
        detections: [BallDetectionResult],
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        timestamp: TimeInterval
    ) -> ARBallDetectionResult {
        
        var ar3DDetections: [AR3DBallDetection] = []
        
        // Convert BallDetectionResult to AR3DBallDetection directly
        // Note: Temporal filtering is already handled by the EnhancedVisionBallDetector
        for detection in detections {
            let ar3DDetection = convertBallDetectionTo3D(
                detection: detection,
                cameraTransform: cameraTransform,
                intrinsics: intrinsics,
                timestamp: timestamp
            )
            ar3DDetections.append(ar3DDetection)
        }
        
        return ARBallDetectionResult(
            detections3D: ar3DDetections,
            processingTime: 0.0, // Will be updated by caller
            frameTimestamp: timestamp,
            cameraTransform: cameraTransform,
            tableInfo: getCurrentTableInfo(),
            performanceMetrics: getPerformanceMetrics()
        )
    }
    
    // MARK: - Individual Detection Conversion
    
    #if canImport(ARKit) && os(iOS)
    private func convertDetectionTo3D(
        detection: FilteredDetection,
        frame: ARFrame,
        timestamp: TimeInterval
    ) -> AR3DBallDetection? {
        
        // Get ball center in screen coordinates
        let ballCenter = CGPoint(x: detection.boundingBox.midX, y: detection.boundingBox.midY)
        
        // Convert to world ray
        let (rayOrigin, rayDirection) = coordinateTransform.screenToWorldRay(ballCenter)
        
        // Calculate depth using multiple methods
        let estimatedDepth = estimateBallDepth(
            detection: detection,
            frame: frame,
            rayOrigin: rayOrigin,
            rayDirection: rayDirection
        )
        
        // Calculate 3D world position
        let worldPosition = rayOrigin + rayDirection * estimatedDepth
        
        // Validate position against table constraints
        guard isValidBallPosition(worldPosition) else {
            return nil
        }
        
        return AR3DBallDetection(
            id: detection.id,
            trackId: detection.trackId,
            boundingBox2D: detection.boundingBox,
            worldPosition: worldPosition,
            confidence: detection.confidence,
            diameter: standardBallDiameter,
            colorResult: detection.colorResult,
            velocity3D: calculateWorld3DVelocity(detection),
            timestamp: timestamp,
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            estimatedDepth: estimatedDepth,
            depthConfidence: calculateDepthConfidence(detection, estimatedDepth)
        )
    }
    #endif
    
    private func convertDetectionTo3D(
        detection: FilteredDetection,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        timestamp: TimeInterval
    ) -> AR3DBallDetection? {
        
        // Get ball center in screen coordinates
        let ballCenter = CGPoint(x: detection.boundingBox.midX, y: detection.boundingBox.midY)
        
        // Convert to world ray
        let (rayOrigin, rayDirection) = coordinateTransform.screenToWorldRay(ballCenter)
        
        // Calculate depth using size-based estimation
        let ballDiameterInPixels = (detection.boundingBox.width + detection.boundingBox.height) / 2
        let estimatedDepth = estimateBallDepthFromSize(
            ballDiameterInPixels: ballDiameterInPixels,
            intrinsics: intrinsics
        )
        
        // Calculate 3D world position
        let worldPosition = rayOrigin + rayDirection * estimatedDepth
        
        // Validate position against table constraints
        guard isValidBallPosition(worldPosition) else {
            return nil
        }
        
        return AR3DBallDetection(
            id: detection.id,
            trackId: detection.trackId,
            boundingBox2D: detection.boundingBox,
            worldPosition: worldPosition,
            confidence: detection.confidence,
            diameter: standardBallDiameter,
            colorResult: detection.colorResult,
            velocity3D: calculateWorld3DVelocity(detection),
            timestamp: timestamp,
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            estimatedDepth: estimatedDepth,
            depthConfidence: calculateDepthConfidence(detection, estimatedDepth)
        )
    }
    
    // MARK: - Depth Estimation
    
    #if canImport(ARKit) && os(iOS)
    private func estimateBallDepth(
        detection: FilteredDetection,
        frame: ARFrame,
        rayOrigin: simd_float3,
        rayDirection: simd_float3
    ) -> Float {
        
        // Method 1: Size-based depth estimation
        let ballDiameterInPixels = (detection.boundingBox.width + detection.boundingBox.height) / 2
        let sizeBasedDepth = estimateBallDepthFromSize(
            ballDiameterInPixels: ballDiameterInPixels,
            intrinsics: frame.camera.intrinsics
        )
        
        // Method 2: Table intersection (if table is detected)
        var tableIntersectionDepth: Float?
        if tableDetectionConfidence > 0.5 {
            tableIntersectionDepth = intersectRayWithTable(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection
            )
        }
        
        // Method 3: Scene depth (if available)
        var sceneDepth: Float?
        if let depthData = frame.sceneDepth?.depthMap {
            sceneDepth = sampleDepthAtPoint(
                depthData: depthData,
                point: CGPoint(x: detection.boundingBox.midX, y: detection.boundingBox.midY),
                imageSize: CGSize(width: CVPixelBufferGetWidth(frame.capturedImage),
                                 height: CVPixelBufferGetHeight(frame.capturedImage))
            )
        }
        
        // Combine depth estimates with confidence weighting
        return combineDepthEstimates(
            sizeBasedDepth: sizeBasedDepth,
            tableIntersectionDepth: tableIntersectionDepth,
            sceneDepth: sceneDepth,
            detection: detection
        )
    }
    #endif
    
    private func estimateBallDepthFromSize(
        ballDiameterInPixels: CGFloat,
        intrinsics: simd_float3x3
    ) -> Float {
        // Use standard ball diameter and camera intrinsics
        let focalLength = (intrinsics[0][0] + intrinsics[1][1]) / 2.0 // Average focal length
        let depth = (standardBallDiameter * focalLength) / Float(ballDiameterInPixels)
        
        // Clamp to reasonable values
        return max(0.1, min(10.0, depth))
    }
    
    private func intersectRayWithTable(
        rayOrigin: simd_float3,
        rayDirection: simd_float3
    ) -> Float? {
        
        guard let tableCenter = tableCenter else { return nil }
        
        // Calculate intersection with table plane
        let tablePoint = simd_float3(tableCenter.x, tableHeight, tableCenter.z)
        let denominator = simd_dot(rayDirection, tableNormal)
        
        // Check if ray is parallel to table
        guard abs(denominator) > 0.001 else { return nil }
        
        let t = simd_dot(tablePoint - rayOrigin, tableNormal) / denominator
        
        // Check if intersection is in front of camera
        guard t > 0 else { return nil }
        
        return t
    }
    
    #if canImport(ARKit) && os(iOS)
    private func sampleDepthAtPoint(
        depthData: CVPixelBuffer,
        point: CGPoint,
        imageSize: CGSize
    ) -> Float? {
        
        CVPixelBufferLockBaseAddress(depthData, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthData, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthData)
        let height = CVPixelBufferGetHeight(depthData)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthData)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthData) else { return nil }
        
        // Convert point to depth buffer coordinates
        let x = Int(point.x * CGFloat(width) / imageSize.width)
        let y = Int(point.y * CGFloat(height) / imageSize.height)
        
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(depthData)
        
        if pixelFormat == kCVPixelFormatType_DepthFloat32 {
            let buffer = baseAddress.assumingMemoryBound(to: Float.self)
            let offset = y * (bytesPerRow / 4) + x
            return buffer[offset]
        } else if pixelFormat == kCVPixelFormatType_DisparityFloat32 {
            // Convert disparity to depth
            let buffer = baseAddress.assumingMemoryBound(to: Float.self)
            let offset = y * (bytesPerRow / 4) + x
            let disparity = buffer[offset]
            return disparity > 0 ? 1.0 / disparity : nil
        }
        
        return nil
    }
    #endif
    
    private func combineDepthEstimates(
        sizeBasedDepth: Float,
        tableIntersectionDepth: Float?,
        sceneDepth: Float?,
        detection: FilteredDetection
    ) -> Float {
        
        var weightedSum: Float = 0
        var totalWeight: Float = 0
        
        // Size-based depth (always available, moderate confidence)
        let sizeWeight: Float = 0.4
        weightedSum += sizeBasedDepth * sizeWeight
        totalWeight += sizeWeight
        
        // Table intersection depth (high confidence if available)
        if let tableDepth = tableIntersectionDepth, tableDetectionConfidence > 0.5 {
            let tableWeight = tableDetectionConfidence * 0.6
            weightedSum += tableDepth * tableWeight
            totalWeight += tableWeight
        }
        
        // Scene depth (highest confidence if available)
        if let depth = sceneDepth {
            let sceneWeight: Float = 0.8
            weightedSum += depth * sceneWeight
            totalWeight += sceneWeight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : sizeBasedDepth
    }
    
    // MARK: - Table Detection
    
    #if canImport(ARKit) && os(iOS)
    private func detectPoolTable(in frame: ARFrame) {
        // Use ARKit plane detection to find horizontal surfaces
        for anchor in frame.anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               planeAnchor.alignment == .horizontal {
                
                // Check if this looks like a pool table (size, height, etc.)
                let planeSize = planeAnchor.planeExtent
                let minTableSize: Float = 1.5 // Minimum 1.5m in any dimension
                
                if planeSize.width >= minTableSize && planeSize.height >= minTableSize {
                    // This could be a pool table
                    updateTableInfo(from: planeAnchor)
                }
            }
        }
    }
    
    private func updateTableInfo(from planeAnchor: ARPlaneAnchor) {
        let transform = planeAnchor.transform
        
        // Extract table properties
        tableHeight = transform.columns.3.y
        tableCenter = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // Calculate table normal from transform
        tableNormal = simd_normalize(simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z))
        
        // Update confidence based on plane stability
        tableDetectionConfidence = min(1.0, tableDetectionConfidence + 0.1)
    }
    #endif
    
    // MARK: - Validation
    
    private func isValidBallPosition(_ worldPosition: simd_float3) -> Bool {
        // Basic sanity checks
        
        // Check if position is too far from camera (beyond reasonable range)
        let distance = simd_length(worldPosition)
        guard distance < 10.0 else { return false } // 10 meters max
        
        // Check if position is above ground level (assuming camera is above table)
        guard worldPosition.y > -2.0 else { return false } // 2 meters below camera max
        
        // If we have table info, check if ball is near table height
        if tableDetectionConfidence > 0.3 {
            let heightDifference = abs(worldPosition.y - tableHeight)
            guard heightDifference < 0.5 else { return false } // 50cm tolerance
        }
        
        return true
    }
    
    // MARK: - Utility Methods
    
    private func calculateWorld3DVelocity(_ detection: FilteredDetection) -> simd_float3 {
        // Convert 2D velocity to 3D using depth information
        let velocity2D = detection.velocity
        
        // For now, assume velocity is mostly in the table plane (XZ)
        // Y component would need more sophisticated tracking
        return simd_float3(velocity2D.x, 0, velocity2D.y)
    }
    
    private func calculateDepthConfidence(_ detection: FilteredDetection, _ depth: Float) -> Float {
        // Calculate confidence based on detection stability and depth estimate quality
        var confidence = detection.confidence
        
        // Boost confidence for stable tracks
        if detection.stabilityScore > 0.7 {
            confidence *= 1.1
        }
        
        // Reduce confidence for extreme depths
        if depth < 0.2 || depth > 5.0 {
            confidence *= 0.8
        }
        
        // Factor in table detection confidence
        if tableDetectionConfidence > 0.5 {
            confidence *= 1.05
        }
        
        return min(1.0, confidence)
    }
    
    private func getCurrentTableInfo() -> ARTableInfo? {
        guard tableDetectionConfidence > 0.3,
              let center = tableCenter else { return nil }
        
        return ARTableInfo(
            center: center,
            height: tableHeight,
            normal: tableNormal,
            confidence: tableDetectionConfidence
        )
    }
    
    private func getPerformanceMetrics() -> [String: Double] {
        var metrics: [String: Double] = [:]
        
        // Add detection metrics
        metrics.merge(enhancedDetector.getPerformanceMetrics()) { _, new in new }
        
        // Add temporal filter metrics
        metrics.merge(temporalFilter.getPerformanceMetrics()) { _, new in new }
        
        // Add AR-specific metrics
        metrics.merge(performanceTracker.getMetrics()) { _, new in new }
        
        return metrics
    }
    
    // MARK: - Public Interface
    
    /// Start the ball detection system
    public func startDetection() throws {
        try enhancedDetector.startDetection()
    }
    
    /// Stop the ball detection system
    public func stopDetection() {
        enhancedDetector.stopDetection()
    }
    
    /// Reset all tracking and detection state
    public func reset() {
        enhancedDetector.reset()
        temporalFilter.reset()
        detectedBalls.removeAll()
        tableDetectionConfidence = 0.0
        tableCenter = nil
        performanceTracker.reset()
    }
    
    /// Get current detection count
    public var currentDetectionCount: Int {
        return detectedBalls.count
    }
    
    /// Update table information manually
    public func updateTableInfo(center: simd_float3, height: Float, normal: simd_float3, confidence: Float) {
        self.tableCenter = center
        self.tableHeight = height
        self.tableNormal = normal
        self.tableDetectionConfidence = confidence
    }
}

// MARK: - Supporting Types

public struct AR3DBallDetection {
    public let id: String
    public let trackId: Int
    public let boundingBox2D: CGRect
    public let worldPosition: simd_float3
    public let confidence: Float
    public let diameter: Float
    public let colorResult: BallColorResult?
    public let velocity3D: simd_float3
    public let timestamp: TimeInterval
    public let rayOrigin: simd_float3
    public let rayDirection: simd_float3
    public let estimatedDepth: Float
    public let depthConfidence: Float
    
    public var ballNumber: Int? {
        return colorResult?.dominantColor?.number
    }
    
    public var isHighConfidence: Bool {
        return confidence > 0.7 && depthConfidence > 0.6
    }
}

public struct ARBallDetectionResult {
    public let detections3D: [AR3DBallDetection]
    public let processingTime: TimeInterval
    public let frameTimestamp: TimeInterval
    public let cameraTransform: simd_float4x4
    public let tableInfo: ARTableInfo?
    public let performanceMetrics: [String: Double]
    
    public var detectionCount: Int {
        return detections3D.count
    }
    
    public var highConfidenceDetections: [AR3DBallDetection] {
        return detections3D.filter { $0.isHighConfidence }
    }
}

public struct ARTableInfo {
    public let center: simd_float3
    public let height: Float
    public let normal: simd_float3
    public let confidence: Float
    
    public var isReliable: Bool {
        return confidence > 0.7
    }
}

// MARK: - Performance Tracker

private class ARPerformanceTracker {
    private var processingTimes: [TimeInterval] = []
    private var frameCount: Int = 0
    
    func updateProcessingTime(_ time: TimeInterval) {
        processingTimes.append(time)
        frameCount += 1
        
        // Keep only recent measurements
        if processingTimes.count > 100 {
            processingTimes.removeFirst()
        }
    }
    
    func getMetrics() -> [String: Double] {
        let avgProcessingTime = processingTimes.isEmpty ? 0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxProcessingTime = processingTimes.max() ?? 0
        
        return [
            "ar_frameCount": Double(frameCount),
            "ar_avgProcessingTime": avgProcessingTime * 1000, // ms
            "ar_maxProcessingTime": maxProcessingTime * 1000, // ms
            "ar_fps": avgProcessingTime > 0 ? 1.0 / avgProcessingTime : 0
        ]
    }
    
    func reset() {
        processingTimes.removeAll()
        frameCount = 0
    }
}

// MARK: - Extensions

extension simd_float4 {
    var xyz: simd_float3 {
        return simd_float3(x, y, z)
    }
}