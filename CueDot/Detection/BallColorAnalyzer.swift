import Foundation
import Vision
import CoreImage
import Accelerate

/// Advanced color analysis for pool ball identification
/// Uses HSV color space analysis and machine learning techniques for robust ball classification
public class BallColorAnalyzer {
    
    // MARK: - Pool Ball Color Definitions
    
    /// Standard pool ball colors in HSV space
    public struct BallColor {
        let name: String
        let number: Int
        let hue: ClosedRange<Float>        // Hue range (0-360)
        let saturation: ClosedRange<Float> // Saturation range (0-1)
        let value: ClosedRange<Float>      // Value/brightness range (0-1)
        let confidence: Float              // Base confidence for this color
        
        init(name: String, number: Int, 
             hue: ClosedRange<Float>, 
             saturation: ClosedRange<Float>, 
             value: ClosedRange<Float>,
             confidence: Float = 0.8) {
            self.name = name
            self.number = number
            self.hue = hue
            self.saturation = saturation
            self.value = value
            self.confidence = confidence
        }
    }
    
    /// Pool ball color database
    public static let poolBallColors: [BallColor] = [
        // Solid balls
        BallColor(name: "Yellow", number: 1, hue: 45...75, saturation: 0.7...1.0, value: 0.6...1.0),
        BallColor(name: "Blue", number: 2, hue: 200...240, saturation: 0.6...1.0, value: 0.4...0.8),
        BallColor(name: "Red", number: 3, hue: 0...20, saturation: 0.7...1.0, value: 0.5...0.9),
        BallColor(name: "Purple", number: 4, hue: 270...300, saturation: 0.6...1.0, value: 0.4...0.8),
        BallColor(name: "Orange", number: 5, hue: 15...45, saturation: 0.7...1.0, value: 0.6...0.9),
        BallColor(name: "Green", number: 6, hue: 90...150, saturation: 0.6...1.0, value: 0.4...0.8),
        BallColor(name: "Maroon", number: 7, hue: 0...20, saturation: 0.6...0.9, value: 0.3...0.6),
        
        // Special balls
        BallColor(name: "Black", number: 8, hue: 0...360, saturation: 0.0...0.3, value: 0.0...0.3, confidence: 0.9),
        BallColor(name: "White", number: 0, hue: 0...360, saturation: 0.0...0.2, value: 0.8...1.0, confidence: 0.9),
        
        // Striped balls (detected by pattern analysis)
        BallColor(name: "Yellow Stripe", number: 9, hue: 45...75, saturation: 0.5...1.0, value: 0.6...1.0, confidence: 0.7),
        BallColor(name: "Blue Stripe", number: 10, hue: 200...240, saturation: 0.4...1.0, value: 0.4...0.8, confidence: 0.7),
        BallColor(name: "Red Stripe", number: 11, hue: 0...20, saturation: 0.5...1.0, value: 0.5...0.9, confidence: 0.7),
        BallColor(name: "Purple Stripe", number: 12, hue: 270...300, saturation: 0.4...1.0, value: 0.4...0.8, confidence: 0.7),
        BallColor(name: "Orange Stripe", number: 13, hue: 15...45, saturation: 0.5...1.0, value: 0.6...0.9, confidence: 0.7),
        BallColor(name: "Green Stripe", number: 14, hue: 90...150, saturation: 0.4...1.0, value: 0.4...0.8, confidence: 0.7),
        BallColor(name: "Maroon Stripe", number: 15, hue: 0...20, saturation: 0.4...0.9, value: 0.3...0.6, confidence: 0.7)
    ]
    
    // MARK: - Analysis Configuration
    
    private let samplingDensity: Int = 5 // Sample every Nth pixel
    private let minimumColorRegionSize: Float = 0.1 // Minimum 10% of ball area
    private let colorConsistencyThreshold: Float = 0.7
    private let stripeDetectionThreshold: Float = 0.3
    
    // MARK: - Color Analysis Cache
    
    private var colorHistogramCache: [String: [Float]] = [:]
    private var recentAnalyses: [(HSVStats, TimeInterval)] = []
    
    // MARK: - Public Interface
    
    public init() {
        // Initialize color analyzer
    }
    
    /// Analyze ball color from Vision observation
    public func analyzeBallColor(
        from observation: VNDetectedObjectObservation,
        in pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    ) -> BallColorResult {
        // Extract ball region from pixel buffer
        guard let ballRegion = extractBallRegion(
            observation: observation,
            pixelBuffer: pixelBuffer,
            imageSize: imageSize
        ) else {
            return BallColorResult.unknown()
        }
        
        // Convert to HSV and analyze
        let hsvStats = analyzeHSVStatistics(ballRegion)
        
        // Detect if ball has stripes
        let hasStripes = detectStripePattern(ballRegion, hsvStats: hsvStats)
        
        // Match against known ball colors
        let colorMatches = matchBallColors(hsvStats, hasStripes: hasStripes)
        
        // Calculate confidence based on color consistency and match quality
        let confidence = calculateColorConfidence(hsvStats, matches: colorMatches)
        
        // Cache analysis for temporal consistency
        cacheAnalysis(hsvStats)
        
        return BallColorResult(
            dominantColor: colorMatches.first,
            alternativeColors: Array(colorMatches.dropFirst()),
            confidence: confidence,
            hasStripes: hasStripes,
            hsvStats: hsvStats,
            analysisTimestamp: Date()
        )
    }
    
    // MARK: - Image Processing
    
    private func extractBallRegion(
        observation: VNDetectedObjectObservation,
        pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    ) -> CIImage? {
        // Lock pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert normalized coordinates to pixel coordinates
        let boundingBox = VNImageRectForNormalizedRect(
            observation.boundingBox,
            Int(imageSize.width),
            Int(imageSize.height)
        )
        
        // Add padding to capture more ball context
        let padding: CGFloat = 10
        let expandedBox = CGRect(
            x: max(0, boundingBox.origin.x - padding),
            y: max(0, boundingBox.origin.y - padding),
            width: min(imageSize.width - boundingBox.origin.x + padding, boundingBox.width + 2 * padding),
            height: min(imageSize.height - boundingBox.origin.y + padding, boundingBox.height + 2 * padding)
        )
        
        // Crop to ball region
        return ciImage.cropped(to: expandedBox)
    }
    
    private func analyzeHSVStatistics(_ ballRegion: CIImage) -> HSVStats {
        // Convert to bitmap for analysis
        guard let cgImage = CIContext().createCGImage(ballRegion, from: ballRegion.extent) else {
            return HSVStats()
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapSize = bytesPerRow * height
        
        guard let bitmapData = malloc(bitmapSize) else {
            return HSVStats()
        }
        defer { free(bitmapData) }
        
        guard let context = CGContext(
            data: bitmapData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return HSVStats()
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Analyze pixels
        let pixelBuffer = bitmapData.assumingMemoryBound(to: UInt8.self)
        
        var hueValues: [Float] = []
        var saturationValues: [Float] = []
        var valueValues: [Float] = []
        var centerHues: [Float] = []
        var edgeHues: [Float] = []
        
        let centerX = width / 2
        let centerY = height / 2
        let centerRadius = min(width, height) / 4
        let edgeRadius = min(width, height) / 2 - 2
        
        for y in stride(from: 0, to: height, by: samplingDensity) {
            for x in stride(from: 0, to: width, by: samplingDensity) {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                
                if pixelIndex + 3 < bitmapSize {
                    let r = Float(pixelBuffer[pixelIndex]) / 255.0
                    let g = Float(pixelBuffer[pixelIndex + 1]) / 255.0
                    let b = Float(pixelBuffer[pixelIndex + 2]) / 255.0
                    
                    let hsv = rgbToHSV(r: r, g: g, b: b)
                    
                    hueValues.append(hsv.h)
                    saturationValues.append(hsv.s)
                    valueValues.append(hsv.v)
                    
                    // Separate center and edge analysis
                    let distanceFromCenter = sqrt(Float((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY)))
                    
                    if distanceFromCenter <= Float(centerRadius) {
                        centerHues.append(hsv.h)
                    } else if distanceFromCenter >= Float(edgeRadius) {
                        edgeHues.append(hsv.h)
                    }
                }
            }
        }
        
        return HSVStats(
            meanHue: calculateMeanHue(hueValues),
            meanSaturation: saturationValues.reduce(0, +) / Float(saturationValues.count),
            meanValue: valueValues.reduce(0, +) / Float(valueValues.count),
            hueVariance: calculateHueVariance(hueValues),
            saturationVariance: calculateVariance(saturationValues),
            valueVariance: calculateVariance(valueValues),
            dominantHueRange: findDominantHueRange(hueValues),
            colorConsistency: calculateColorConsistency(hueValues, saturationValues),
            centerHue: calculateMeanHue(centerHues),
            edgeHue: calculateMeanHue(edgeHues),
            totalSamples: hueValues.count
        )
    }
    
    // MARK: - Color Space Conversion
    
    private func rgbToHSV(r: Float, g: Float, b: Float) -> (h: Float, s: Float, v: Float) {
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min
        
        // Value
        let v = max
        
        // Saturation
        let s = max == 0 ? 0 : delta / max
        
        // Hue
        var h: Float = 0
        if delta != 0 {
            if max == r {
                h = 60 * ((g - b) / delta)
            } else if max == g {
                h = 60 * (2 + (b - r) / delta)
            } else if max == b {
                h = 60 * (4 + (r - g) / delta)
            }
            
            if h < 0 {
                h += 360
            }
        }
        
        return (h: h, s: s, v: v)
    }
    
    // MARK: - Statistical Analysis
    
    private func calculateMeanHue(_ hues: [Float]) -> Float {
        if hues.isEmpty { return 0 }
        
        // Handle circular nature of hue values
        var sinSum: Float = 0
        var cosSum: Float = 0
        
        for hue in hues {
            let radians = hue * Float.pi / 180.0
            sinSum += sin(radians)
            cosSum += cos(radians)
        }
        
        let meanRadians = atan2(sinSum / Float(hues.count), cosSum / Float(hues.count))
        var meanHue = meanRadians * 180.0 / Float.pi
        
        if meanHue < 0 {
            meanHue += 360
        }
        
        return meanHue
    }
    
    private func calculateHueVariance(_ hues: [Float]) -> Float {
        if hues.count < 2 { return 0 }
        
        let meanHue = calculateMeanHue(hues)
        var variance: Float = 0
        
        for hue in hues {
            let diff = min(abs(hue - meanHue), 360 - abs(hue - meanHue))
            variance += diff * diff
        }
        
        return variance / Float(hues.count - 1)
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        if values.count < 2 { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(values.count - 1)
        
        return variance
    }
    
    private func calculateColorConsistency(_ hues: [Float], _ saturations: [Float]) -> Float {
        let hueConsistency = 1.0 - min(1.0, sqrt(calculateHueVariance(hues)) / 60.0)
        let saturationConsistency = 1.0 - min(1.0, sqrt(calculateVariance(saturations)))
        
        return (hueConsistency + saturationConsistency) / 2.0
    }
    
    private func findDominantHueRange(_ hues: [Float]) -> ClosedRange<Float> {
        if hues.isEmpty { return 0...0 }
        
        // Create hue histogram
        var histogram: [Int] = Array(repeating: 0, count: 36) // 10-degree bins
        
        for hue in hues {
            let bin = Int(hue / 10.0) % 36
            histogram[bin] += 1
        }
        
        // Find dominant range
        let maxCount = histogram.max() ?? 0
        guard maxCount > 0 else { return 0...0 }
        
        let dominantBin = histogram.firstIndex(of: maxCount) ?? 0
        let startHue = Float(dominantBin * 10)
        let endHue = Float((dominantBin + 1) * 10)
        
        return startHue...endHue
    }
    
    // MARK: - Pattern Detection
    
    private func detectStripePattern(_ ballRegion: CIImage, hsvStats: HSVStats) -> Bool {
        // Simple stripe detection based on color variance and edge analysis
        let edgeVarianceThreshold: Float = 0.5
        let centerEdgeHueDifference = abs(hsvStats.centerHue - hsvStats.edgeHue)
        let normalizedHueDifference = min(centerEdgeHueDifference, 360 - centerEdgeHueDifference)
        
        // Check for significant color variation between center and edges
        let hasColorVariation = normalizedHueDifference > 30 || hsvStats.hueVariance > edgeVarianceThreshold
        
        // Check for low color consistency (indicating multiple colors)
        let hasLowConsistency = hsvStats.colorConsistency < colorConsistencyThreshold
        
        return hasColorVariation && hasLowConsistency
    }
    
    // MARK: - Color Matching
    
    private func matchBallColors(_ hsvStats: HSVStats, hasStripes: Bool) -> [BallColor] {
        var matches: [(color: BallColor, score: Float)] = []
        
        let candidateColors = hasStripes ? 
            Self.poolBallColors.filter { $0.name.contains("Stripe") || $0.number == 0 } :
            Self.poolBallColors.filter { !$0.name.contains("Stripe") }
        
        for ballColor in candidateColors {
            let score = calculateColorMatchScore(hsvStats, ballColor: ballColor)
            if score > 0.3 { // Minimum match threshold
                matches.append((color: ballColor, score: score))
            }
        }
        
        // Sort by score (best matches first)
        matches.sort { $0.score > $1.score }
        
        return matches.map { $0.color }
    }
    
    private func calculateColorMatchScore(_ hsvStats: HSVStats, ballColor: BallColor) -> Float {
        // Hue match score
        let hueScore = calculateHueMatchScore(hsvStats.meanHue, ballColor.hue)
        
        // Saturation match score
        let saturationScore = ballColor.saturation.contains(hsvStats.meanSaturation) ? 1.0 : 
                            max(0.0, 1.0 - min(
                                abs(hsvStats.meanSaturation - ballColor.saturation.lowerBound),
                                abs(hsvStats.meanSaturation - ballColor.saturation.upperBound)
                            ))
        
        // Value match score
        let valueScore = ballColor.value.contains(hsvStats.meanValue) ? 1.0 :
                        max(0.0, 1.0 - min(
                            abs(hsvStats.meanValue - ballColor.value.lowerBound),
                            abs(hsvStats.meanValue - ballColor.value.upperBound)
                        ))
        
        // Color consistency bonus
        let consistencyBonus: Float = hsvStats.colorConsistency > colorConsistencyThreshold ? 1.2 : 1.0
        
        // Weighted combination - broken down to avoid compiler complexity
        let baseScore = (hueScore * 0.5) + (saturationScore * 0.3) + (valueScore * 0.2)
        let bonusAdjusted = baseScore * consistencyBonus
        let finalScore = bonusAdjusted * ballColor.confidence
        
        return min(1.0, finalScore)
    }
    
    private func calculateHueMatchScore(_ hue: Float, _ hueRange: ClosedRange<Float>) -> Float {
        if hueRange.contains(hue) {
            return 1.0
        }
        
        // Handle circular nature of hue
        let lowerDistance = min(abs(hue - hueRange.lowerBound), 360 - abs(hue - hueRange.lowerBound))
        let upperDistance = min(abs(hue - hueRange.upperBound), 360 - abs(hue - hueRange.upperBound))
        let minDistance = min(lowerDistance, upperDistance)
        
        // Exponential decay for distance
        return max(0.0, exp(-minDistance / 30.0))
    }
    
    private func calculateColorConfidence(_ hsvStats: HSVStats, matches: [BallColor]) -> Float {
        guard let bestMatch = matches.first else { return 0.0 }
        
        // Base confidence from color match
        let matchScore = calculateColorMatchScore(hsvStats, ballColor: bestMatch)
        
        // Color consistency factor
        let consistencyFactor = hsvStats.colorConsistency
        
        // Sample size factor
        let sampleFactor = min(1.0, Float(hsvStats.totalSamples) / 100.0)
        
        // Temporal consistency (if available)
        let temporalFactor = calculateTemporalConsistency(hsvStats)
        
        return matchScore * consistencyFactor * sampleFactor * temporalFactor
    }
    
    // MARK: - Temporal Analysis
    
    private func cacheAnalysis(_ hsvStats: HSVStats) {
        recentAnalyses.append((hsvStats, Date().timeIntervalSince1970))
        
        // Keep only recent analyses (last 5 seconds)
        let currentTime = Date().timeIntervalSince1970
        recentAnalyses = recentAnalyses.filter { currentTime - $1 < 5.0 }
        
        // Limit cache size
        if recentAnalyses.count > 30 {
            recentAnalyses.removeFirst()
        }
    }
    
    private func calculateTemporalConsistency(_ currentStats: HSVStats) -> Float {
        if recentAnalyses.count < 3 { return 1.0 }
        
        let recentHues = recentAnalyses.map { $0.0.meanHue }
        let hueConsistency = 1.0 - min(1.0, sqrt(calculateHueVariance(recentHues)) / 60.0)
        
        return max(0.5, hueConsistency) // Minimum 0.5 factor
    }
}

// MARK: - Supporting Types

public struct HSVStats {
    let meanHue: Float
    let meanSaturation: Float
    let meanValue: Float
    let hueVariance: Float
    let saturationVariance: Float
    let valueVariance: Float
    let dominantHueRange: ClosedRange<Float>
    let colorConsistency: Float
    let centerHue: Float
    let edgeHue: Float
    let totalSamples: Int
    
    init(meanHue: Float = 0,
         meanSaturation: Float = 0,
         meanValue: Float = 0,
         hueVariance: Float = 0,
         saturationVariance: Float = 0,
         valueVariance: Float = 0,
         dominantHueRange: ClosedRange<Float> = 0...0,
         colorConsistency: Float = 0,
         centerHue: Float = 0,
         edgeHue: Float = 0,
         totalSamples: Int = 0) {
        self.meanHue = meanHue
        self.meanSaturation = meanSaturation
        self.meanValue = meanValue
        self.hueVariance = hueVariance
        self.saturationVariance = saturationVariance
        self.valueVariance = valueVariance
        self.dominantHueRange = dominantHueRange
        self.colorConsistency = colorConsistency
        self.centerHue = centerHue
        self.edgeHue = edgeHue
        self.totalSamples = totalSamples
    }
}

public struct BallColorResult {
    public let dominantColor: BallColorAnalyzer.BallColor?
    public let alternativeColors: [BallColorAnalyzer.BallColor]
    public let confidence: Float
    public let hasStripes: Bool
    public let hsvStats: HSVStats
    public let analysisTimestamp: Date
    
    public static func unknown() -> BallColorResult {
        return BallColorResult(
            dominantColor: nil,
            alternativeColors: [],
            confidence: 0.0,
            hasStripes: false,
            hsvStats: HSVStats(),
            analysisTimestamp: Date()
        )
    }
    
    /// Analyze a region image for ball color characteristics
    /// - Parameter regionImage: CIImage containing the ball region to analyze
    /// - Returns: BallColorResult containing analysis results
    public func analyzeRegion(_ regionImage: CIImage) -> BallColorResult {
        guard let cgImage = CIContext().createCGImage(regionImage, from: regionImage.extent) else {
            return BallColorResult(
                dominantColor: nil,
                alternativeColors: [],
                confidence: 0.0,
                hasStripes: false,
                hsvStats: HSVStats(meanHue: 0, meanSaturation: 0, meanValue: 0),
                analysisTimestamp: Date()
            )
        }
        
        // Convert to HSV and analyze
        // TODO: Implement HSV statistics extraction and ball color classification
        let hsvStats = HSVStats(meanHue: 0, meanSaturation: 0, meanValue: 0)
        
        return BallColorResult(
            dominantColor: nil,
            alternativeColors: [],
            confidence: 0.0,
            hasStripes: false,
            hsvStats: hsvStats,
            analysisTimestamp: Date()
        )
    }
    
    /// Reset analyzer state and clear caches
    public func reset() {
        // Clear any internal state if needed
        // Currently no persistent state to reset in this implementation
    }
}