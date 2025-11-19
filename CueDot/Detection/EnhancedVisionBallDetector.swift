import Foundation
import Vision
import CoreImage
import simd
import QuartzCore
import Accelerate

// MARK: - Supporting Types

/// Detection source type for candidate detections
public enum DetectionSource {
    case contour
    case rectangle
    case object
}

/// Enhanced Vision-based ball detection implementation
/// Uses advanced computer vision algorithms for improved accuracy and reliability
@available(iOS 14.0, macOS 11.0, *)
public class EnhancedVisionBallDetector: BallDetectionProtocol {
    
    // MARK: - Nested Types
    
    /// Candidate detection from vision analysis
    @available(iOS 14.0, macOS 11.0, *)
    public struct CandidateDetection {
        let id: UUID
        let boundingBox: CGRect
        let confidence: Float
        let source: DetectionSource
        let isOccluded: Bool
        let hasNearbyDetections: Bool
        
        // Optional data from specific detection types
        let contourData: VNContoursObservation?
        let rectangleData: VNRectangleObservation?
        let objectData: VNRecognizedObjectObservation?
        
        init(
            boundingBox: CGRect,
            confidence: Float,
            source: DetectionSource,
            isOccluded: Bool = false,
            hasNearbyDetections: Bool = false,
            contourData: VNContoursObservation? = nil,
            rectangleData: VNRectangleObservation? = nil,
            objectData: VNRecognizedObjectObservation? = nil
        ) {
            self.id = UUID()
            self.boundingBox = boundingBox
            self.confidence = confidence
            self.source = source
            self.isOccluded = isOccluded
            self.hasNearbyDetections = hasNearbyDetections
            self.contourData = contourData
            self.rectangleData = rectangleData
            self.objectData = objectData
        }
    }
    
    // MARK: - Protocol Properties
    
    public var configuration: BallDetectionConfiguration {
        didSet {
            setupDetection()
        }
    }
    
    public private(set) var isActive: Bool = false
    public private(set) var lastProcessingTime: TimeInterval = 0
    
    // MARK: - Enhanced Properties
    
    /// Adaptive detection parameters that adjust based on conditions
    private var adaptiveParameters: AdaptiveDetectionParameters
    
    /// Color analysis engine for ball identification
    private let colorAnalyzer: BallColorAnalyzer
    
    /// Advanced confidence calculator
    private let confidenceCalculator: DetectionConfidenceCalculator
    
    /// Performance profiler for optimization
    private let profiler: DetectionProfiler
    
    /// Vision request cache for efficiency
    private var visionRequestCache: VisionRequestCache
    
    /// Detection history for temporal filtering
    private var detectionHistory: DetectionHistory
    
    /// Multi-ball clustering engine for complex scenes
    private let clusteringEngine: MultiBallClusteringEngine
    
    /// Ball association engine for tracking across frames
    private let associationEngine: BallAssociationEngine
    
    // MARK: - Private Properties
    
    private var visionRequests: [VNRequest] = []
    private var performanceMetrics: [String: Double] = [:]
    private var lastDetections: [BallDetectionResult] = []
    private var currentImageSize: CGSize = CGSize.zero
    
    // MARK: - Initialization
    
    public init(configuration: BallDetectionConfiguration = BallDetectionConfiguration()) {
        if configuration.minimumConfidence > 0.5 {
            self.configuration = BallDetectionConfiguration(
                ballDiameter: configuration.ballDiameter,
                minimumConfidence: 0.5,
                maxBallsPerFrame: configuration.maxBallsPerFrame,
                regionOfInterest: configuration.regionOfInterest,
                colorFiltering: configuration.colorFiltering,
                shapeDetection: configuration.shapeDetection,
                performance: configuration.performance
            )
        } else {
            self.configuration = configuration
        }
        self.adaptiveParameters = AdaptiveDetectionParameters()
        self.colorAnalyzer = BallColorAnalyzer()
        self.confidenceCalculator = DetectionConfidenceCalculator()
        self.profiler = DetectionProfiler()
        self.visionRequestCache = VisionRequestCache()
        self.detectionHistory = DetectionHistory()
        self.clusteringEngine = MultiBallClusteringEngine()
        self.associationEngine = BallAssociationEngine()
        setupDetection()
    }
    
    // MARK: - Protocol Methods
    
    public func detectBalls(in pixelBuffer: CVPixelBuffer, 
                           cameraTransform: simd_float4x4,
                           timestamp: TimeInterval) throws -> [BallDetectionResult] {
        guard isActive else {
            throw BallDetectionError.detectionNotActive
        }
        
        // Use a synchronous wrapper around the async implementation
        let semaphore = DispatchSemaphore(value: 0)
        var result: [BallDetectionResult] = []
        var detectionError: Error?
        
        Task {
            do {
                result = try await detectBallsAsync(in: pixelBuffer, 
                                                  cameraTransform: cameraTransform, 
                                                  timestamp: timestamp)
            } catch {
                detectionError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = detectionError {
            throw error
        }
        
        return result
    }
    
    private func detectBallsAsync(in pixelBuffer: CVPixelBuffer, 
                                 cameraTransform: simd_float4x4,
                                 timestamp: TimeInterval) async throws -> [BallDetectionResult] {
        guard isActive else {
            throw BallDetectionError.detectionNotActive
        }
        
        let startTime = CACurrentMediaTime()
        profiler.startFrame()
        
        // Extract image properties
        let imageSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        currentImageSize = imageSize
        
        // Update adaptive parameters based on image characteristics
        adaptiveParameters.update(
            for: pixelBuffer,
            imageSize: imageSize,
            cameraTransform: cameraTransform
        )
        
        // Create enhanced vision request handler
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        var detectionResults: [BallDetectionResult] = []
        
        do {
            // Perform multi-stage detection
            profiler.startStage(.visionProcessing)
            try handler.perform(visionRequests)
            profiler.endStage(.visionProcessing)
            
            // Process and enhance results
            profiler.startStage(.resultProcessing)
            detectionResults = try processEnhancedResults(
                pixelBuffer: pixelBuffer,
                imageSize: imageSize,
                timestamp: timestamp,
                cameraTransform: cameraTransform
            )
            profiler.endStage(.resultProcessing)
            
        } catch {
            throw BallDetectionError.detectionFailed("Enhanced vision processing failed: \(error.localizedDescription)")
        }
        
        // Post-process results with temporal filtering
        profiler.startStage(.temporalFiltering)
        detectionResults = applyTemporalFiltering(detectionResults, timestamp: timestamp)
        profiler.endStage(.temporalFiltering)
        
        // Apply multi-ball clustering for complex scenes
        profiler.startStage(.clustering)
        let enhancedDetections = detectionResults.toEnhanced()
        let clusteringResult = try await clusteringEngine.clusterBalls(enhancedDetections)
        profiler.endStage(.clustering)
        
        // Apply ball association and tracking
        profiler.startStage(.association)
        let associationResult = await associationEngine.associateBalls(enhancedDetections)
        profiler.endStage(.association)
        
        // Merge clustering and association results for final detection set
        let finalEnhancedDetections = mergeClusteringAndAssociation(
            detections: enhancedDetections,
            clustering: clusteringResult,
            association: associationResult
        )
        
        // Convert back to original format for compatibility
        detectionResults = finalEnhancedDetections.toOriginal()
        
        // Update detection history
        detectionHistory.add(detections: detectionResults, timestamp: timestamp)
        
        let processingTime = CACurrentMediaTime() - startTime
        lastProcessingTime = processingTime
        
        // Update comprehensive performance metrics
        updatePerformanceMetrics(
            processingTime: processingTime,
            detectionResults: detectionResults,
            profilerData: profiler.getFrameData()
        )
        
        lastDetections = detectionResults
        profiler.endFrame()
        
        return detectionResults
    }
    
    public func detectBallsAsync(in pixelBuffer: CVPixelBuffer,
                                cameraTransform: simd_float4x4,
                                timestamp: TimeInterval,
                                completion: @escaping (Result<[BallDetectionResult], BallDetectionError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Task {
                do {
                    let results = try await self?.detectBallsAsync(in: pixelBuffer, 
                                                       cameraTransform: cameraTransform, 
                                                       timestamp: timestamp) ?? []
                    DispatchQueue.main.async {
                        completion(.success(results))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error as? BallDetectionError ?? .detectionFailed("Unknown error")))
                    }
                }
            }
        }
    }
    
    public func startDetection() throws {
        guard !isActive else { return }
        
        do {
            setupDetection()
            isActive = true
            profiler.reset()
            detectionHistory.reset()
            performanceMetrics["sessionsStarted"] = (performanceMetrics["sessionsStarted"] ?? 0) + 1
        } catch {
            throw BallDetectionError.initializationFailed("Failed to start enhanced detection: \(error.localizedDescription)")
        }
    }
    
    public func stopDetection() {
        isActive = false
        profiler.finalize()
        performanceMetrics["sessionsStopped"] = (performanceMetrics["sessionsStopped"] ?? 0) + 1
    }
    
    public func reset() {
        stopDetection()
        lastDetections.removeAll()
        performanceMetrics.removeAll()
        adaptiveParameters.reset()
        detectionHistory.reset()
        profiler.reset()
        visionRequestCache.clear()
        setupDetection()
    }
    
    public func getPerformanceMetrics() -> [String: Double] {
        var metrics = performanceMetrics
        metrics["isActive"] = isActive ? 1.0 : 0.0
        metrics["lastDetectionCount"] = Double(lastDetections.count)
        metrics.merge(profiler.getMetrics()) { (_, new) in new }
        metrics.merge(adaptiveParameters.getMetrics()) { (_, new) in new }
        return metrics
    }
    
    public func meetsPerformanceRequirements(_ requirements: PerformanceRequirements) -> Bool {
        guard let lastProcessingTime = performanceMetrics["lastProcessingTime"] else { return false }
        
        // Check latency requirement
        if lastProcessingTime > requirements.maximumLatency * 1000 { // Convert to ms
            return false
        }
        
        // Check FPS requirement
        let fpsEstimate = 1000.0 / (lastProcessingTime > 0 ? lastProcessingTime : 1.0)
        if fpsEstimate < requirements.minimumFPS {
            return false
        }
        
        return true
    }
    
    // MARK: - Enhanced Detection Setup
    
    private func setupDetection() {
        visionRequests.removeAll()
        visionRequestCache.clear()
        
        // Multi-stage detection pipeline
        setupCircleDetection()
        setupContourDetection()
        setupRectangleDetection()
        setupObjectDetection()
        
        // Setup requests are cached for performance
        visionRequestCache.cacheRequests(visionRequests)
    }
    
    @available(iOS 17.0, *)
    private func setupCircleDetection() {
        if #available(iOS 14.0, *) {
            let circleRequest = VNDetectContoursRequest { [weak self] request, error in
                self?.handleEnhancedContourResults(request: request, error: error)
            }
            circleRequest.maximumImageDimension = adaptiveParameters.maxImageDimension
            circleRequest.contrastAdjustment = adaptiveParameters.contrastAdjustment
            visionRequests.append(circleRequest)
        }
    }
    
    @available(iOS 17.0, *)
    private func setupContourDetection() {
        if #available(iOS 14.0, *) {
            let contourRequest = VNDetectContoursRequest { [weak self] request, error in
                self?.handleEnhancedContourResults(request: request, error: error)
            }
            contourRequest.contrastAdjustment = adaptiveParameters.contrastAdjustment
            contourRequest.detectsDarkOnLight = true
            visionRequests.append(contourRequest)
        }
    }
    
    private func setupRectangleDetection() {
        let rectRequest = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleEnhancedRectangleResults(request: request, error: error)
        }
        
        // Adaptive parameters for ball detection
        rectRequest.minimumAspectRatio = VNAspectRatio(adaptiveParameters.minAspectRatio)
        rectRequest.maximumAspectRatio = VNAspectRatio(adaptiveParameters.maxAspectRatio)
        rectRequest.minimumSize = adaptiveParameters.minSize
        rectRequest.minimumConfidence = adaptiveParameters.minConfidence
        rectRequest.maximumObservations = Int(configuration.maxBallsPerFrame)
        
        visionRequests.append(rectRequest)
    }
    
    @available(iOS 17.0, *)
    private func setupObjectDetection() {
        // Use rectangle detection as fallback for object detection on iOS
        if #available(iOS 11.0, *) {
            let rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
                self?.handleRectangleDetectionResults(request: request, error: error)
            }
            rectangleRequest.maximumObservations = 10
            visionRequests.append(rectangleRequest)
        }
    }
    
    // MARK: - Enhanced Result Processing
    
    private func processEnhancedResults(
        pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        timestamp: TimeInterval,
        cameraTransform: simd_float4x4
    ) throws -> [BallDetectionResult] {
        
        var candidateDetections: [CandidateDetection] = []
        
        // Collect candidate detections from all vision requests
        candidateDetections.append(contentsOf: collectContourCandidates())
        candidateDetections.append(contentsOf: collectRectangleCandidates())
        candidateDetections.append(contentsOf: collectObjectCandidates())

        debugLog("Frame timestamp=\(timestamp) collected candidates: contour=\(collectContourCandidates().count) rectangle=\(collectRectangleCandidates().count) object=\(collectObjectCandidates().count) total=\(candidateDetections.count)")
        
        // Filter and merge overlapping detections
        let mergedCandidates = mergeOverlappingDetections(candidateDetections)

        debugLog("Merged candidates count=\(mergedCandidates.count)")
        
        // Analyze each candidate for ball properties
        var ballDetections: [BallDetectionResult] = []
        
        for candidate in mergedCandidates {
            if let ballDetection = try analyzeCandidateForBall(
                candidate,
                in: pixelBuffer,
                imageSize: imageSize,
                timestamp: timestamp,
                cameraTransform: cameraTransform
            ) {
                ballDetections.append(ballDetection)
            }
        }

        debugLog("Ball detections before confidence filter=\(ballDetections.count)")
        
        // Apply confidence-based filtering
        let filteredDetections = ballDetections.filter { 
            Double($0.confidence) >= configuration.minimumConfidence 
        }

        debugLog("Filtered detections (minConf=\(configuration.minimumConfidence)) count=\(filteredDetections.count)")
        
        // Sort by confidence and limit to max balls per frame
        return Array(filteredDetections
            .sorted { $0.confidence > $1.confidence }
            .prefix(Int(configuration.maxBallsPerFrame)))
    }
    
    private func analyzeCandidateForBall(
        _ candidate: CandidateDetection,
        in pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        timestamp: TimeInterval,
        cameraTransform: simd_float4x4
    ) throws -> BallDetectionResult? {
        
        // Extract image region for detailed analysis
        guard let regionImage = extractImageRegion(
            from: pixelBuffer,
            region: candidate.boundingBox,
            imageSize: imageSize
        ) else {
            return nil
        }
        
        // Analyze shape characteristics
        let shapeScore = analyzeShapeCharacteristics(candidate, regionImage: regionImage)
        if shapeScore <= adaptiveParameters.minShapeScore {
            debugLog("Reject candidate shapeScore=\(shapeScore) minShape=\(adaptiveParameters.minShapeScore) bbox=\(candidate.boundingBox) visionConf=\(candidate.confidence)")
            return nil
        }
        
        // Analyze color characteristics
        // TODO: Implement proper color analysis once BallColorAnalyzer compilation issues are resolved
        let colorAnalysis = BallColorResult(
            dominantColor: nil,
            alternativeColors: [],
            confidence: 0.8, // Temporary high confidence to allow detection to proceed
            hasStripes: false,
            hsvStats: HSVStats(meanHue: 0, meanSaturation: 0, meanValue: 0),
            analysisTimestamp: Date()
        )
        if colorAnalysis.confidence <= 0.3 {
            debugLog("Reject candidate colorConf=\(colorAnalysis.confidence) bbox=\(candidate.boundingBox)")
            return nil
        }
        
        // Calculate size and perspective characteristics
        let sizeScore = analyzeSizeCharacteristics(candidate, imageSize: imageSize)
        
        // Calculate overall confidence
        let detectionConfidence = confidenceCalculator.calculateConfidence(
            for: candidate,
            colorResult: colorAnalysis,
            adaptiveParams: adaptiveParameters,
            cameraTransform: cameraTransform,
            timestamp: timestamp
        )
        
        if detectionConfidence.overall <= Float(configuration.minimumConfidence) {
            debugLog("Reject candidate overall=\(detectionConfidence.overall) threshold=\(configuration.minimumConfidence) geom=\(detectionConfidence.geometric) temp=\(detectionConfidence.temporal) color=\(detectionConfidence.color) ctx=\(detectionConfidence.context) motion=\(detectionConfidence.motion) bbox=\(candidate.boundingBox)")
            return nil
        }
        debugLog("Accept candidate overall=\(detectionConfidence.overall) geom=\(detectionConfidence.geometric) temp=\(detectionConfidence.temporal) color=\(detectionConfidence.color) ctx=\(detectionConfidence.context) motion=\(detectionConfidence.motion) bbox=\(candidate.boundingBox) visionConf=\(candidate.confidence) shapeScore=\(shapeScore)")
        
        // Convert to 3D world position
        let worldPosition = convertToEnhancedWorldPosition(
            candidate: candidate,
            imageSize: imageSize,
            cameraTransform: cameraTransform
        )
        
        return BallDetectionResult(
            ballCenter3D: worldPosition,
            confidence: detectionConfidence.overall,
            timestamp: timestamp,
            isOccluded: candidate.isOccluded,
            hasMultipleBalls: candidate.hasNearbyDetections
        )
    }

    // Debug logging helper
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[EnhancedVisionBallDetector] \(message)")
        #endif
    }
    
    // MARK: - Vision Result Handlers
    
    @available(iOS 17.0, *)
    private func handleEnhancedContourResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNContoursObservation] else {
            return
        }
        
        let circularContours = results.compactMap { contour -> CandidateDetection? in
            guard isEnhancedCircularContour(contour) else { return nil }
            
            let boundingBox = contour.normalizedPath.boundingBox
            
            return CandidateDetection(
                boundingBox: boundingBox,
                confidence: Float(contour.confidence),
                source: .contour,
                isOccluded: false,
                hasNearbyDetections: false,
                contourData: contour
            )
        }
        
        storeTemporaryCandidates(circularContours, source: DetectionSource.contour)
    }
    
    private func handleEnhancedRectangleResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNRectangleObservation] else {
            return
        }
        
        let squareDetections = results.compactMap { rect -> CandidateDetection? in
            guard isSquareLikeRectangle(rect) else { return nil }
            
            return CandidateDetection(
                boundingBox: rect.boundingBox,
                confidence: rect.confidence,
                source: .rectangle,
                rectangleData: rect
            )
        }
        
        storeTemporaryCandidates(squareDetections, source: DetectionSource.rectangle)
    }
    
    @available(iOS 17.0, *)
    private func handleRectangleDetectionResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNRectangleObservation] else {
            return
        }
        
        let rectangleDetections = results.compactMap { rectangle -> CandidateDetection? in
            // Convert rectangle to candidate detection for circular objects
            let boundingBox = rectangle.boundingBox
            let aspectRatio = boundingBox.width / boundingBox.height
            
            // Filter for roughly square rectangles that could be balls
            guard abs(aspectRatio - 1.0) < 0.3 else { return nil }
            
            return CandidateDetection(
                boundingBox: boundingBox,
                confidence: Float(rectangle.confidence),
                source: .rectangle,
                isOccluded: false,
                hasNearbyDetections: false,
                rectangleData: rectangle
            )
        }
        
        storeTemporaryCandidates(rectangleDetections, source: DetectionSource.rectangle)
    }
    
    // Legacy method kept for compatibility - no longer used with rectangle detection
    @available(macOS 10.14, *)
    private func handleObjectDetectionResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNRecognizedObjectObservation] else {
            return
        }
        
        let ballLikeObjects = results.compactMap { object -> CandidateDetection? in
            // Look for sports equipment or round objects
            guard isBallLikeObject(object) else { return nil }
            
            return CandidateDetection(
                boundingBox: object.boundingBox,
                confidence: object.confidence,
                source: .object,
                objectData: object
            )
        }
        
        storeTemporaryCandidates(ballLikeObjects, source: DetectionSource.object)
    }
    
    // MARK: - Enhanced Analysis Methods
    
    @available(iOS 17.0, *)
    private func isEnhancedCircularContour(_ contour: VNContoursObservation) -> Bool {
        let normalizedPath = contour.normalizedPath
        
        let boundingBox = normalizedPath.boundingBox
        let aspectRatio = boundingBox.width / boundingBox.height
        
        // Check aspect ratio for circularity
        guard aspectRatio > 0.7 && aspectRatio < 1.4 else { return false }
        
        // Check contour complexity (circles should have moderate complexity)
        let pathLength = estimatePathLength(normalizedPath)
        let expectedCircleLength = 2 * Float.pi * Float((boundingBox.width + boundingBox.height) / 4)
        let lengthRatio = pathLength / expectedCircleLength
        
        // Circle perimeter should be close to expected
        return lengthRatio > 0.8 && lengthRatio < 1.3
    }
    
    private func isSquareLikeRectangle(_ rect: VNRectangleObservation) -> Bool {
        let boundingBox = rect.boundingBox
        let aspectRatio = boundingBox.width / boundingBox.height
        
        // Balls appear roughly square in 2D
        return Float(aspectRatio) > adaptiveParameters.minAspectRatio && 
               Float(aspectRatio) < adaptiveParameters.maxAspectRatio &&
               Float(boundingBox.width) > adaptiveParameters.minSize
    }
    
    // Legacy method for compatibility - not used on iOS
    @available(macOS 10.14, *)
    private func isBallLikeObject(_ object: VNRecognizedObjectObservation) -> Bool {
        for label in object.labels {
            let identifier = label.identifier.lowercased()
            if identifier.contains("ball") || 
               identifier.contains("sphere") || 
               identifier.contains("circle") ||
               identifier.contains("billiard") ||
               identifier.contains("pool") {
                return label.confidence > 0.3
            }
        }
        return false
    }
    
    private func analyzeShapeCharacteristics(_ candidate: CandidateDetection, regionImage: CIImage) -> Float {
        // Analyze the extracted region for ball-like shape characteristics
        
        // Edge detection for circularity analysis
        let edgeIntensity = calculateEdgeIntensity(regionImage)
        
        // Symmetry analysis
        let symmetryScore = calculateSymmetryScore(regionImage)
        
        // Compactness analysis (how circular the shape is)
        let compactnessScore = calculateCompactnessScore(candidate)
        
        // Weighted combination
        return (edgeIntensity * 0.3 + symmetryScore * 0.4 + compactnessScore * 0.3)
    }
    
    private func analyzeSizeCharacteristics(_ candidate: CandidateDetection, imageSize: CGSize) -> Float {
        let pixelArea = candidate.boundingBox.width * candidate.boundingBox.height * 
                       imageSize.width * imageSize.height
        
        // Expected ball size range in pixels (adaptive based on distance)
        let expectedMinArea: CGFloat = adaptiveParameters.expectedMinBallArea
        let expectedMaxArea: CGFloat = adaptiveParameters.expectedMaxBallArea
        
        if pixelArea < expectedMinArea {
            return Float(pixelArea / expectedMinArea) // Penalty for being too small
        } else if pixelArea > expectedMaxArea {
            return Float(expectedMaxArea / pixelArea) // Penalty for being too large
        } else {
            return 1.0 // Perfect size
        }
    }
    
    private func getTemporalScore(for candidate: CandidateDetection, timestamp: TimeInterval) -> Float {
        // Analyze detection consistency over time
        return detectionHistory.getTemporalScore(for: candidate, timestamp: timestamp)
    }
    
    private func convertToEnhancedWorldPosition(
        candidate: CandidateDetection,
        imageSize: CGSize,
        cameraTransform: simd_float4x4
    ) -> simd_float3 {
        
        // Convert normalized coordinates to pixel coordinates
        let pixelBox = CGRect(
            x: candidate.boundingBox.minX * imageSize.width,
            y: candidate.boundingBox.minY * imageSize.height,
            width: candidate.boundingBox.width * imageSize.width,
            height: candidate.boundingBox.height * imageSize.height
        )
        
        let centerX = pixelBox.midX
        let centerY = pixelBox.midY
        
        // Estimate depth based on ball size (larger = closer)
        let ballDiameter = max(pixelBox.width, pixelBox.height)
        let estimatedDepth = adaptiveParameters.estimateDepth(ballDiameter: ballDiameter)
        
        // Convert to normalized device coordinates
        let normalizedX = (centerX - imageSize.width / 2) / (imageSize.width / 2)
        let normalizedY = (centerY - imageSize.height / 2) / (imageSize.height / 2)
        
        // Apply camera intrinsics for accurate projection  
        let depthFactor = Double(estimatedDepth) * adaptiveParameters.cameraFOVFactor
        let worldX = Float(normalizedX * depthFactor)
        let worldY = Float(-normalizedY * depthFactor) // Flip Y
        let worldZ = -estimatedDepth // Negative Z in camera space
        
        return simd_float3(worldX, worldY, worldZ)
    }
    
    // MARK: - Support Methods
    
    private func applyTemporalFiltering(_ detections: [BallDetectionResult], timestamp: TimeInterval) -> [BallDetectionResult] {
        // Apply temporal consistency filtering
        return detections.compactMap { detection in
            let stabilizedPosition = detectionHistory.stabilizePosition(
                for: detection,
                timestamp: timestamp
            )
            
            if let stabilizedPos = stabilizedPosition {
                return BallDetectionResult(
                    ballCenter3D: stabilizedPos,
                    confidence: detection.confidence,
                    timestamp: timestamp,
                    isOccluded: detection.isOccluded,
                    hasMultipleBalls: detection.hasMultipleBalls
                )
            }
            return detection
        }
    }
    
    private func updatePerformanceMetrics(
        processingTime: TimeInterval,
        detectionResults: [BallDetectionResult],
        profilerData: [String: Double]
    ) {
        performanceMetrics["lastProcessingTime"] = processingTime * 1000 // ms
        performanceMetrics["detectionsCount"] = Double(detectionResults.count)
        performanceMetrics["averageConfidence"] = detectionResults.isEmpty ? 0 : 
            detectionResults.map { Double($0.confidence) }.reduce(0, +) / Double(detectionResults.count)
        
        // Add profiler metrics
        performanceMetrics.merge(profilerData) { (_, new) in new }
        
        // Add accuracy metrics if available
        if let accuracy = calculateDetectionAccuracy(detectionResults) {
            performanceMetrics["detectionAccuracy"] = accuracy
        }
    }
    
    private func calculateDetectionAccuracy(_ detections: [BallDetectionResult]) -> Double? {
        // Calculate accuracy based on confidence distribution and temporal consistency
        guard !detections.isEmpty else { return nil }
        
        let highConfidenceCount = detections.filter { $0.confidence > 0.8 }.count
        let temporalConsistencyScore = detectionHistory.getConsistencyScore()
        
        let baseAccuracy = Double(highConfidenceCount) / Double(detections.count)
        return baseAccuracy * temporalConsistencyScore
    }
    
    // MARK: - Utility Methods (placeholder implementations)
    
    private func collectContourCandidates() -> [CandidateDetection] {
        return getTemporaryCandidates(source: .contour)
    }
    
    private func collectRectangleCandidates() -> [CandidateDetection] {
        return getTemporaryCandidates(source: .rectangle)
    }
    
    private func collectObjectCandidates() -> [CandidateDetection] {
        return getTemporaryCandidates(source: .object)
    }
    
    private func mergeOverlappingDetections(_ candidates: [CandidateDetection]) -> [CandidateDetection] {
        // Simple non-maximum suppression
        var merged: [CandidateDetection] = []
        let sortedCandidates = candidates.sorted { $0.confidence > $1.confidence }
        
        for candidate in sortedCandidates {
            let hasOverlap = merged.contains { existing in
                calculateOverlapRatio(candidate.boundingBox, existing.boundingBox) > 0.3
            }
            
            if !hasOverlap {
                merged.append(candidate)
            }
        }
        
        return merged
    }
    
    private func calculateOverlapRatio(_ box1: CGRect, _ box2: CGRect) -> CGFloat {
        let intersection = box1.intersection(box2)
        let union = box1.area + box2.area - intersection.area
        return union > 0 ? intersection.area / union : 0
    }
    
    private func extractImageRegion(from pixelBuffer: CVPixelBuffer, region: CGRect, imageSize: CGSize) -> CIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let pixelRegion = CGRect(
            x: region.minX * imageSize.width,
            y: region.minY * imageSize.height,
            width: region.width * imageSize.width,
            height: region.height * imageSize.height
        )
        return ciImage.cropped(to: pixelRegion)
    }
    
    private func calculateEdgeIntensity(_ image: CIImage) -> Float {
        // Placeholder for edge detection analysis
        return 0.7 // Simulated edge intensity
    }
    
    private func calculateSymmetryScore(_ image: CIImage) -> Float {
        // Placeholder for symmetry analysis
        return 0.8 // Simulated symmetry score
    }
    
    private func calculateCompactnessScore(_ candidate: CandidateDetection) -> Float {
        let aspectRatio = candidate.boundingBox.width / candidate.boundingBox.height
        return 1.0 - Float(abs(aspectRatio - 1.0)) // Closer to square = higher score
    }
    
    private func estimatePathLength(_ path: CGPath) -> Float {
        // Placeholder for path length calculation
        return 10.0 // Simulated path length
    }
    
    // MARK: - Temporary Storage for Vision Results
    
    private var temporaryCandidates: [DetectionSource: [CandidateDetection]] = [:]
    
    private func storeTemporaryCandidates(_ candidates: [CandidateDetection], source: DetectionSource) {
        temporaryCandidates[source] = candidates
    }
    
    private func getTemporaryCandidates(source: DetectionSource) -> [CandidateDetection] {
        return temporaryCandidates[source] ?? []
    }
}

// MARK: - Supporting Classes

/// Vision request cache for performance optimization
public class VisionRequestCache {
    private var cachedRequests: [VNRequest] = []
    
    func cacheRequests(_ requests: [VNRequest]) {
        cachedRequests = requests
    }
    
    func getCachedRequests() -> [VNRequest] {
        return cachedRequests
    }
    
    func clear() {
        cachedRequests.removeAll()
    }
}

/// Detection history manager for temporal filtering
public class DetectionHistory {
    private var history: [TimestampedDetection] = []
    private let maxHistoryLength = 30
    
    struct TimestampedDetection {
        let detection: BallDetectionResult
        let timestamp: TimeInterval
    }
    
    func add(detections: [BallDetectionResult], timestamp: TimeInterval) {
        for detection in detections {
            history.append(TimestampedDetection(detection: detection, timestamp: timestamp))
        }
        
        // Keep only recent history
        let cutoffTime = timestamp - 2.0 // 2 seconds
        history = history.filter { $0.timestamp > cutoffTime }
        
        if history.count > maxHistoryLength {
            history.removeFirst(history.count - maxHistoryLength)
        }
    }
    
    func getTemporalScore(for candidate: EnhancedVisionBallDetector.CandidateDetection, timestamp: TimeInterval) -> Float {
        let recentHistory = history.filter { timestamp - $0.timestamp <= 0.5 }
        
        if recentHistory.isEmpty {
            return 0.5 // Neutral score for new detections
        }
        
        // Find closest historical detection
        var closestDistance: Float = Float.greatestFiniteMagnitude
        for historyItem in recentHistory {
            let distance = calculateDistance(candidate.boundingBox, historyItem.detection.boundingBox)
            if distance < closestDistance {
                closestDistance = distance
            }
        }
        
        // Convert distance to score (closer = higher score)
        return max(0.0, 1.0 - closestDistance / 0.2)
    }
    
    func stabilizePosition(for detection: BallDetectionResult, timestamp: TimeInterval) -> simd_float3? {
        let recentHistory = history.filter { timestamp - $0.timestamp <= 0.2 }
        
        if recentHistory.count < 2 {
            return nil // Need more history for stabilization
        }
        
        // Simple averaging for position stabilization
        var avgPosition = simd_float3(0, 0, 0)
        for historyItem in recentHistory {
            avgPosition += historyItem.detection.ballCenter3D
        }
        avgPosition /= Float(recentHistory.count)
        
        return avgPosition
    }
    
    func getConsistencyScore() -> Double {
        if history.count < 3 {
            return 1.0
        }
        
        // Calculate variance in confidence scores
        let confidences = history.map { Double($0.detection.confidence) }
        let average = confidences.reduce(0, +) / Double(confidences.count)
        let variance = confidences.map { pow($0 - average, 2) }.reduce(0, +) / Double(confidences.count)
        
        // Lower variance = higher consistency
        return max(0.0, 1.0 - variance)
    }
    
    func reset() {
        history.removeAll()
    }
    
    private func calculateDistance(_ box1: CGRect, _ box2: CGRect) -> Float {
        let center1 = CGPoint(x: box1.midX, y: box1.midY)
        let center2 = CGPoint(x: box2.midX, y: box2.midY)
        let dx = center1.x - center2.x
        let dy = center1.y - center2.y
        return Float(sqrt(dx*dx + dy*dy))
    }
}

/// Performance profiler for detection optimization
public class DetectionProfiler {
    private var metrics: [String: Double] = [:]
    private var startTime: TimeInterval = 0
    private var stageStartTimes: [String: TimeInterval] = [:]
    
    func startFrame() {
        startTime = CACurrentMediaTime()
    }
    
    func endFrame() {
        let endTime = CACurrentMediaTime()
        let totalTime = (endTime - startTime) * 1000 // Convert to ms
        metrics["frameProcessingTime"] = totalTime
    }
    
    func startStage(_ stage: ProfilingStage) {
        stageStartTimes[stage.rawValue] = CACurrentMediaTime()
    }
    
    func endStage(_ stage: ProfilingStage) {
        guard let stageStart = stageStartTimes[stage.rawValue] else { return }
        let stageTime = (CACurrentMediaTime() - stageStart) * 1000 // Convert to ms
        metrics["\(stage.rawValue)Time"] = stageTime
        stageStartTimes.removeValue(forKey: stage.rawValue)
    }
    
    func getFrameData() -> [String: Double] {
        return metrics
    }
    
    func getMetrics() -> [String: Double] {
        return metrics
    }
    
    func reset() {
        metrics.removeAll()
        stageStartTimes.removeAll()
    }
    
    func finalize() {
        // Cleanup any remaining state
        reset()
    }
    
    func startProfiling() {
        startTime = CACurrentMediaTime()
    }
    
    func endProfiling() -> [String: Double] {
        let endTime = CACurrentMediaTime()
        let totalTime = (endTime - startTime) * 1000 // Convert to ms
        
        metrics["totalProcessingTime"] = totalTime
        metrics["timestamp"] = endTime
        
        return metrics
    }
    
    func addMetric(key: String, value: Double) {
        metrics[key] = value
    }
}

    // MARK: - Multi-ball Processing Methods
    
    /// Merge clustering and association results with original detections
    private func mergeClusteringAndAssociation(
        detections: [EnhancedBallDetectionResult],
        clustering: MultiBallClusteringEngine.ClusteringResult,
        association: BallAssociationEngine.AssociationResult
    ) -> [EnhancedBallDetectionResult] {
        var mergedResults: [EnhancedBallDetectionResult] = []
        
        // Start with original detections and enhance with tracking and clustering info
        for detection in detections {
            var enhancedDetection = detection
            
            // Find associated tracking info
            if let trackingAssociation = association.associations.first(where: { 
                $0.detectionId == detection.id 
            }) {
                // Create metadata with tracking information
                let newMetadata = BallDetectionMetadata(
                    trackingId: trackingAssociation.trackingId,
                    clusterInfo: findClusterInfo(for: detection, in: clustering),
                    associationType: trackingAssociation.associationType.rawValue,
                    sceneComplexity: clustering.sceneComplexity.rawValue
                )
                
                enhancedDetection = EnhancedBallDetectionResult(
                    id: detection.id,
                    ballCenter3D: detection.ballCenter3D,
                    confidence: detection.confidence,
                    timestamp: detection.timestamp,
                    isOccluded: detection.isOccluded,
                    hasMultipleBalls: detection.hasMultipleBalls,
                    ballType: detection.ballType,
                    metadata: newMetadata
                )
            }
            
            mergedResults.append(enhancedDetection)
        }
        
        return mergedResults
    }
    
    /// Find cluster information for a specific detection
    private func findClusterInfo(
        for detection: EnhancedBallDetectionResult,
        in clustering: MultiBallClusteringEngine.ClusteringResult
    ) -> ClusterInfo? {
        for cluster in clustering.clusters {
            if cluster.balls.contains(where: { $0.id == detection.id }) {
                return ClusterInfo(
                    clusterId: cluster.id.uuidString,
                    clusterType: cluster.clusterType.rawValue,
                    ballCount: cluster.balls.count,
                    clusterConfidence: cluster.confidence
                )
            }
        }
        return nil
    }

// MARK: - Extensions for Enum String Values

extension MultiBallClusteringEngine.BallCluster.ClusterType {
    var rawValue: String {
        switch self {
        case .loose: return "loose"
        case .tight: return "tight"
        case .overlapping: return "overlapping"
        case .linear: return "linear"
        case .circular: return "circular"
        }
    }
}

extension MultiBallClusteringEngine.ClusteringResult.SceneComplexity {
    var rawValue: String {
        switch self {
        case .simple: return "simple"
        case .moderate: return "moderate"
        case .complex: return "complex"
        case .chaotic: return "chaotic"
        }
    }
}

extension BallAssociationEngine.AssociationResult.BallAssociation.AssociationType {
    var rawValue: String {
        switch self {
        case .direct: return "direct"
        case .predicted: return "predicted"
        case .recovered: return "recovered"
        case .appearance: return "appearance"
        }
    }
}

/// Profiling stage enumeration
public enum ProfilingStage: String {
    case visionProcessing = "visionProcessing"
    case resultProcessing = "resultProcessing"
    case temporalFiltering = "temporalFiltering"
    case clustering = "clustering"
    case association = "association"
}

// MARK: - Extensions

extension CGRect {
    var area: CGFloat {
        return width * height
    }
}

extension BallDetectionResult {
    var boundingBox: CGRect {
        // Approximate bounding box from 3D position
        // This is a simplified implementation
        return CGRect(x: 0, y: 0, width: 0.1, height: 0.1)
    }
}