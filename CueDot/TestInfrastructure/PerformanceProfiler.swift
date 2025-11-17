import Foundation
import simd
#if canImport(os)
import os
#endif

/// Performance profiler for tracking and analyzing performance metrics during testing
/// Monitors frame rates, latency, memory usage, and processing time
@available(iOS 17.0, *)
public class PerformanceProfiler {
    
    // MARK: - Performance Metrics
    
    /// Current performance metrics
    public struct PerformanceMetrics {
        /// Average frame rate (FPS)
        public let averageFrameRate: Double
        
        /// Current frame rate (instantaneous)
        public let currentFrameRate: Double
        
        /// Average frame time in milliseconds
        public let averageFrameTime: Double
        
        /// Frame time variance (jitter)
        public let frameTimeVariance: Double
        
        /// Total frames processed
        public let totalFrames: UInt64
        
        /// Dropped frame count
        public let droppedFrames: UInt64
        
        /// Average memory usage in MB
        public let averageMemoryUsage: Double
        
        /// Peak memory usage in MB
        public let peakMemoryUsage: Double
        
        /// Average CPU usage percentage
        public let averageCPUUsage: Double
        
        /// Peak CPU usage percentage
        public let peakCPUUsage: Double
        
        /// Total profiling duration in seconds
        public let profilingDuration: TimeInterval
        
        /// Performance score (0.0 to 1.0)
        public let performanceScore: Double
        
        public init(
            averageFrameRate: Double = 0.0,
            currentFrameRate: Double = 0.0,
            averageFrameTime: Double = 0.0,
            frameTimeVariance: Double = 0.0,
            totalFrames: UInt64 = 0,
            droppedFrames: UInt64 = 0,
            averageMemoryUsage: Double = 0.0,
            peakMemoryUsage: Double = 0.0,
            averageCPUUsage: Double = 0.0,
            peakCPUUsage: Double = 0.0,
            profilingDuration: TimeInterval = 0.0,
            performanceScore: Double = 0.0
        ) {
            self.averageFrameRate = averageFrameRate
            self.currentFrameRate = currentFrameRate
            self.averageFrameTime = averageFrameTime
            self.frameTimeVariance = frameTimeVariance
            self.totalFrames = totalFrames
            self.droppedFrames = droppedFrames
            self.averageMemoryUsage = averageMemoryUsage
            self.peakMemoryUsage = peakMemoryUsage
            self.averageCPUUsage = averageCPUUsage
            self.peakCPUUsage = peakCPUUsage
            self.profilingDuration = profilingDuration
            self.performanceScore = performanceScore
        }
    }
    
    // MARK: - Configuration
    
    /// Profiling configuration
    public struct ProfilingConfiguration {
        /// Target frame rate for performance calculations
        public let targetFrameRate: Int
        
        /// Maximum frame time before considering dropped
        public let maxFrameTime: TimeInterval
        
        /// Sample buffer size for rolling averages
        public let sampleBufferSize: Int
        
        /// Performance measurement interval
        public let measurementInterval: TimeInterval
        
        /// Enable detailed CPU monitoring
        public let enableCPUMonitoring: Bool
        
        /// Enable detailed memory monitoring
        public let enableMemoryMonitoring: Bool
        
        public init(
            targetFrameRate: Int = 60,
            maxFrameTime: TimeInterval = 0.033, // ~30fps threshold
            sampleBufferSize: Int = 120, // 2 seconds at 60fps
            measurementInterval: TimeInterval = 0.1,
            enableCPUMonitoring: Bool = true,
            enableMemoryMonitoring: Bool = true
        ) {
            self.targetFrameRate = targetFrameRate
            self.maxFrameTime = maxFrameTime
            self.sampleBufferSize = sampleBufferSize
            self.measurementInterval = measurementInterval
            self.enableCPUMonitoring = enableCPUMonitoring
            self.enableMemoryMonitoring = enableMemoryMonitoring
        }
    }
    
    // MARK: - Private Properties
    
    /// Profiling configuration
    private let configuration: ProfilingConfiguration
    
    /// Whether profiling is currently active
    private var isActive = false
    
    /// Profiling start time
    private var startTime: Date?
    
    /// Frame timing data
    private var frameTimes: [TimeInterval] = []
    
    /// Frame timestamps
    private var frameTimestamps: [TimeInterval] = []
    
    /// Memory usage samples
    private var memoryUsageSamples: [Double] = []
    
    /// CPU usage samples
    private var cpuUsageSamples: [Double] = []
    
    /// Previous frame timestamp for delta calculation
    private var previousFrameTimestamp: TimeInterval = 0.0
    
    /// Total frames processed
    private var frameCount: UInt64 = 0
    
    /// Dropped frame count
    private var droppedFrameCount: UInt64 = 0
    
    /// Peak memory usage recorded
    private var peakMemory: Double = 0.0
    
    /// Peak CPU usage recorded
    private var peakCPU: Double = 0.0
    
    /// Timer for periodic measurements
    private var measurementTimer: Timer?
    
    /// Performance calculation cache
    private var metricsCache: PerformanceMetrics?
    
    /// Cache invalidation timestamp
    private var cacheTimestamp: TimeInterval = 0.0
    
    /// Cache validity duration
    private let cacheValidityDuration: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    /// Initialize performance profiler with configuration
    /// - Parameter configuration: Profiling configuration
    public init(configuration: ProfilingConfiguration = ProfilingConfiguration()) {
        self.configuration = configuration
    }
    
    deinit {
        stopProfiling()
    }
    
    // MARK: - Profiling Control
    
    /// Start performance profiling
    public func startProfiling() {
        guard !isActive else { return }
        
        reset()
        isActive = true
        startTime = Date()
        
        // Start periodic measurements
        if configuration.enableCPUMonitoring || configuration.enableMemoryMonitoring {
            startPeriodicMeasurements()
        }
        
        logMessage("Performance profiling started")
    }
    
    /// Stop performance profiling
    public func stopProfiling() {
        guard isActive else { return }
        
        isActive = false
        measurementTimer?.invalidate()
        measurementTimer = nil
        
        logMessage("Performance profiling stopped")
    }
    
    /// Record a frame processing time
    /// This should be called once per frame
    public func recordFrameTime() {
        guard isActive else { return }
        
        let currentTime = getCurrentTimestamp()
        
        if previousFrameTimestamp > 0 {
            let frameTime = currentTime - previousFrameTimestamp
            
            // Add to rolling buffer directly (avoid double counting)
            frameTimes.append(frameTime)
            frameTimestamps.append(currentTime)
            
            // Maintain buffer size
            if frameTimes.count > configuration.sampleBufferSize {
                frameTimes.removeFirst()
                frameTimestamps.removeFirst()
            }
            
            // Check for dropped frames
            if frameTime > configuration.maxFrameTime {
                droppedFrameCount += 1
            }
            
            // Invalidate metrics cache
            invalidateCache()
        }
        
        previousFrameTimestamp = currentTime
        frameCount += 1
    }
    
    /// Record a specific frame processing time
    /// - Parameter frameTime: Frame processing time in seconds
    public func recordFrameTime(_ frameTime: TimeInterval) {
        guard isActive else { return }
        
        // Add to rolling buffer
        frameTimes.append(frameTime)
        frameTimestamps.append(getCurrentTimestamp())
        
        // Maintain buffer size
        if frameTimes.count > configuration.sampleBufferSize {
            frameTimes.removeFirst()
            frameTimestamps.removeFirst()
        }
        
        // Check for dropped frames
        if frameTime > configuration.maxFrameTime {
            droppedFrameCount += 1
        }
        
        // Increment frame count for manual recordings too
        frameCount += 1
        
        // Invalidate metrics cache
        invalidateCache()
    }
    
    /// Record processing time for a specific operation
    /// - Parameters:
    ///   - operationName: Name of the operation
    ///   - processingTime: Processing time in seconds
    public func recordProcessingTime(for operationName: String, processingTime: TimeInterval) {
        guard isActive else { return }
        
        let processingTimeMs = processingTime * 1000.0
        logMessage("Operation '\(operationName)': \(String(format: "%.2f", processingTimeMs))ms")
    }
    
    /// Start timing an operation
    /// - Parameter operationName: Name of the operation
    /// - Returns: Operation token for ending timing
    public func startTiming(for operationName: String) -> OperationTimer {
        return OperationTimer(profiler: self, operationName: operationName, startTime: getCurrentTimestamp())
    }
    
    // MARK: - Metrics Retrieval
    
    /// Get current performance metrics
    /// - Returns: Current performance metrics
    public func getCurrentMetrics() -> PerformanceMetrics {
        // Return cached metrics if still valid
        if let cached = metricsCache,
           getCurrentTimestamp() - cacheTimestamp < cacheValidityDuration {
            return cached
        }
        
        let metrics = calculateCurrentMetrics()
        
        // Cache the metrics
        metricsCache = metrics
        cacheTimestamp = getCurrentTimestamp()
        
        return metrics
    }
    
    /// Get performance metrics as dictionary for easy inspection
    /// - Returns: Dictionary of performance metrics
    public func getCurrentMetricsAsDictionary() -> [String: Double] {
        let metrics = getCurrentMetrics()
        
        return [
            "averageFrameRate": metrics.averageFrameRate,
            "currentFrameRate": metrics.currentFrameRate,
            "averageFrameTime": metrics.averageFrameTime,
            "frameTimeVariance": metrics.frameTimeVariance,
            "totalFrames": Double(metrics.totalFrames),
            "droppedFrames": Double(metrics.droppedFrames),
            "averageMemoryUsage": metrics.averageMemoryUsage,
            "peakMemoryUsage": metrics.peakMemoryUsage,
            "averageCPUUsage": metrics.averageCPUUsage,
            "peakCPUUsage": metrics.peakCPUUsage,
            "profilingDuration": metrics.profilingDuration,
            "performanceScore": metrics.performanceScore
        ]
    }
    
    /// Generate performance report as formatted string
    /// - Returns: Human-readable performance report
    public func generateReport() -> String {
        let metrics = getCurrentMetrics()
        
        var report = "=== Performance Report ===\n"
        report += "Duration: \(String(format: "%.1f", metrics.profilingDuration))s\n"
        report += "Total Frames: \(metrics.totalFrames)\n"
        report += "Dropped Frames: \(metrics.droppedFrames)\n"
        report += "Average FPS: \(String(format: "%.1f", metrics.averageFrameRate))\n"
        report += "Current FPS: \(String(format: "%.1f", metrics.currentFrameRate))\n"
        report += "Average Frame Time: \(String(format: "%.2f", metrics.averageFrameTime))ms\n"
        report += "Frame Time Variance: \(String(format: "%.2f", metrics.frameTimeVariance))ms\n"
        
        if configuration.enableMemoryMonitoring {
            report += "Average Memory: \(String(format: "%.1f", metrics.averageMemoryUsage))MB\n"
            report += "Peak Memory: \(String(format: "%.1f", metrics.peakMemoryUsage))MB\n"
        }
        
        if configuration.enableCPUMonitoring {
            report += "Average CPU: \(String(format: "%.1f", metrics.averageCPUUsage))%%\n"
            report += "Peak CPU: \(String(format: "%.1f", metrics.peakCPUUsage))%%\n"
        }
        
        report += "Performance Score: \(String(format: "%.2f", metrics.performanceScore))\n"
        
        return report
    }
    
    // MARK: - Utility Methods
    
    /// Reset all performance data
    public func reset() {
        frameTimes.removeAll()
        frameTimestamps.removeAll()
        memoryUsageSamples.removeAll()
        cpuUsageSamples.removeAll()
        frameCount = 0
        droppedFrameCount = 0
        peakMemory = 0.0
        peakCPU = 0.0
        previousFrameTimestamp = 0.0
        startTime = nil
        invalidateCache()
    }
    
    /// Check if profiler meets performance requirements
    /// - Parameters:
    ///   - targetFPS: Target frame rate
    ///   - maxMemoryMB: Maximum memory usage in MB
    ///   - maxDroppedFrameRatio: Maximum ratio of dropped frames
    /// - Returns: Whether performance requirements are met
    public func meetsPerformanceRequirements(
        targetFPS: Double = 60.0,
        maxMemoryMB: Double = 100.0,
        maxDroppedFrameRatio: Double = 0.05
    ) -> Bool {
        let metrics = getCurrentMetrics()
        
        let fpsOK = metrics.averageFrameRate >= targetFPS * 0.9 // 90% of target
        let memoryOK = metrics.averageMemoryUsage <= maxMemoryMB
        let droppedFrameRatioOK = (Double(metrics.droppedFrames) / Double(max(metrics.totalFrames, 1))) <= maxDroppedFrameRatio
        
        return fpsOK && memoryOK && droppedFrameRatioOK
    }
    
    // MARK: - Private Methods
    
    private func calculateCurrentMetrics() -> PerformanceMetrics {
        guard isActive, !frameTimes.isEmpty else {
            return PerformanceMetrics()
        }
        
        // Calculate frame rate metrics
        let averageFrameTime = frameTimes.reduce(0.0, +) / Double(frameTimes.count)
        let averageFrameRate = averageFrameTime > 0 ? 1.0 / averageFrameTime : 0.0
        
        // Calculate current frame rate (last few frames)
        let recentFrameCount = min(10, frameTimes.count)
        let recentFrameTimes = Array(frameTimes.suffix(recentFrameCount))
        let recentAverage = recentFrameTimes.reduce(0.0, +) / Double(recentFrameTimes.count)
        let currentFrameRate = recentAverage > 0 ? 1.0 / recentAverage : 0.0
        
        // Calculate frame time variance
        let variance = frameTimes.map { pow($0 - averageFrameTime, 2) }.reduce(0.0, +) / Double(frameTimes.count)
        let frameTimeVariance = sqrt(variance)
        
        // Calculate memory metrics
        let averageMemory = memoryUsageSamples.isEmpty ? 0.0 : memoryUsageSamples.reduce(0.0, +) / Double(memoryUsageSamples.count)
        
        // Calculate CPU metrics
        let averageCPU = cpuUsageSamples.isEmpty ? 0.0 : cpuUsageSamples.reduce(0.0, +) / Double(cpuUsageSamples.count)
        
        // Calculate profiling duration
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0.0
        
        // Calculate performance score
        let score = calculatePerformanceScore(
            frameRate: averageFrameRate,
            variance: frameTimeVariance,
            droppedFrameRatio: Double(droppedFrameCount) / Double(max(frameCount, 1))
        )
        
        return PerformanceMetrics(
            averageFrameRate: averageFrameRate,
            currentFrameRate: currentFrameRate,
            averageFrameTime: averageFrameTime * 1000.0, // Convert to ms
            frameTimeVariance: frameTimeVariance * 1000.0, // Convert to ms
            totalFrames: frameCount,
            droppedFrames: droppedFrameCount,
            averageMemoryUsage: averageMemory,
            peakMemoryUsage: peakMemory,
            averageCPUUsage: averageCPU,
            peakCPUUsage: peakCPU,
            profilingDuration: duration,
            performanceScore: score
        )
    }
    
    private func calculatePerformanceScore(
        frameRate: Double,
        variance: Double,
        droppedFrameRatio: Double
    ) -> Double {
        let targetFPS = Double(configuration.targetFrameRate)
        
        // Frame rate score (0.0 to 1.0)
        let fpsScore = min(1.0, frameRate / targetFPS)
        
        // Variance score (lower variance = higher score)
        let maxAcceptableVariance = 0.005 // 5ms
        let varianceScore = max(0.0, 1.0 - (variance / maxAcceptableVariance))
        
        // Dropped frame score
        let maxAcceptableDropRatio = 0.05 // 5%
        let dropScore = max(0.0, 1.0 - (droppedFrameRatio / maxAcceptableDropRatio))
        
        // Weighted average
        let score = (fpsScore * 0.5) + (varianceScore * 0.3) + (dropScore * 0.2)
        
        return max(0.0, min(1.0, score))
    }
    
    private func startPeriodicMeasurements() {
        measurementTimer = Timer.scheduledTimer(withTimeInterval: configuration.measurementInterval, repeats: true) { [weak self] _ in
            self?.takeMeasurement()
        }
    }
    
    private func takeMeasurement() {
        if configuration.enableMemoryMonitoring {
            let memoryUsage = getCurrentMemoryUsage()
            memoryUsageSamples.append(memoryUsage)
            peakMemory = max(peakMemory, memoryUsage)
            
            // Maintain sample buffer size
            if memoryUsageSamples.count > configuration.sampleBufferSize {
                memoryUsageSamples.removeFirst()
            }
        }
        
        if configuration.enableCPUMonitoring {
            let cpuUsage = getCurrentCPUUsage()
            cpuUsageSamples.append(cpuUsage)
            peakCPU = max(peakCPU, cpuUsage)
            
            // Maintain sample buffer size
            if cpuUsageSamples.count > configuration.sampleBufferSize {
                cpuUsageSamples.removeFirst()
            }
        }
        
        invalidateCache()
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage estimation
        // In a real implementation, you'd use more sophisticated methods
        return Double.random(in: 0.0...100.0) // Mock implementation for testing
    }
    
    private func getCurrentTimestamp() -> TimeInterval {
        return Date().timeIntervalSince1970
    }
    
    private func invalidateCache() {
        metricsCache = nil
        cacheTimestamp = 0.0
    }
    
    private func logMessage(_ message: String) {
        #if DEBUG
        if #available(iOS 14.0, macOS 11.0, *) {
            let logger = Logger(subsystem: "com.cuedot.performance", category: "profiler")
            logger.info("\(message)")
        } else {
            print("[PerformanceProfiler] \(message)")
        }
        #endif
    }
}

// MARK: - Operation Timer

/// Timer for measuring individual operation performance
public class OperationTimer {
    private weak var profiler: PerformanceProfiler?
    private let operationName: String
    private let startTime: TimeInterval
    
    internal init(profiler: PerformanceProfiler, operationName: String, startTime: TimeInterval) {
        self.profiler = profiler
        self.operationName = operationName
        self.startTime = startTime
    }
    
    /// End timing and record the result
    public func end() {
        let endTime = Date().timeIntervalSince1970
        let processingTime = endTime - startTime
        profiler?.recordProcessingTime(for: operationName, processingTime: processingTime)
    }
}

// MARK: - Performance Test Utilities

/// Utilities for performance testing
public extension PerformanceProfiler {
    
    /// Run a performance test on a block of code
    /// - Parameters:
    ///   - testName: Name of the test
    ///   - iterations: Number of iterations to run
    ///   - block: Code block to test
    /// - Returns: Performance metrics for the test
    @discardableResult
    static func performanceTest(
        testName: String,
        iterations: Int = 100,
        block: () throws -> Void
    ) rethrows -> PerformanceMetrics {
        let profiler = PerformanceProfiler()
        profiler.startProfiling()
        
        for _ in 0..<iterations {
            let timer = profiler.startTiming(for: testName)
            try block()
            timer.end()
        }
        
        Thread.sleep(forTimeInterval: 0.1) // Allow final measurements
        let metrics = profiler.getCurrentMetrics()
        profiler.stopProfiling()
        
        return metrics
    }
}