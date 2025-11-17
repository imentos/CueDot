import Foundation
#if canImport(RealityKit)
import RealityKit
#endif
#if canImport(ARKit)
import ARKit
#endif
import simd
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(Metal)
import Metal
#endif

// Platform-specific type aliases
#if canImport(UIKit)
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
public typealias PlatformColor = NSColor
#else
// Fallback for unsupported platforms
public struct PlatformColor {
    public static let blue = PlatformColor()
    public static let yellow = PlatformColor()
    public static let green = PlatformColor()
}
#endif

// Color scheme for theming
public struct PlatformColorScheme {
    public let primary: PlatformColor
    public let secondary: PlatformColor
    public let accent: PlatformColor
    
    public init(primary: PlatformColor, secondary: PlatformColor, accent: PlatformColor) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
    }
}

#if canImport(RealityKit) && canImport(ARKit)
@available(iOS 13.0, macOS 10.15, *)
public typealias PlatformARView = ARView
#else
// Fallback ARView for non-AR platforms
public class PlatformARView {
    public init() {}
}
#endif

/// Protocol defining the interface for AR rendering systems
/// Implementations should handle visual overlays, trajectory visualization, and UI guidance
@available(iOS 13.0, macOS 10.15, *)
public protocol ARRendererProtocol {
    
    // MARK: - Configuration
    
    /// Configuration settings for the renderer
    var configuration: ARRendererConfiguration { get set }
    
    /// Whether the renderer is currently active
    var isActive: Bool { get }
    
    /// Current rendering mode
    var renderingMode: RenderingMode { get set }
    
    // MARK: - Rendering Methods
    
    /// Render ball overlays and trajectories
    /// - Parameters:
    ///   - balls: Currently tracked balls to render
    ///   - arView: ARView to render into
    ///   - cameraTransform: Current camera transform
    /// - Throws: ARRendererError if rendering fails
    func renderBalls(_ balls: [TrackedBall], in arView: PlatformARView, cameraTransform: simd_float4x4) throws
    
    /// Render trajectory predictions
    /// - Parameters:
    ///   - trajectories: Dictionary of ball UUIDs to trajectory point arrays
    ///   - arView: PlatformARView to render into
    ///   - showProbability: Whether to show uncertainty bounds
    /// - Throws: ARRendererError if rendering fails
    func renderTrajectories(_ trajectories: [UUID: [TrajectoryPoint]],
                           in arView: PlatformARView,
                           showProbability: Bool) throws    /// Render cue alignment guidance
    /// - Parameters:
    ///   - cuePosition: Current cue position and orientation
    ///   - targetBall: Target ball information
    ///   - pocketTarget: Target pocket for the shot
    ///   - arView: PlatformARView to render into
    /// - Throws: ARRendererError if rendering fails
    func renderCueGuidance(cuePosition: CuePosition,
                          targetBall: TrackedBall,
                          pocketTarget: PocketPosition,
                          in arView: PlatformARView) throws
    
    /// Render table surface detection and boundaries
    /// - Parameters:
    ///   - tableGeometry: Detected table surface information
    ///   - arView: PlatformARView to render into
    /// - Throws: ARRendererError if rendering fails
    func renderTable(_ tableGeometry: TableGeometry, in arView: PlatformARView) throws
    
    /// Render shot analysis overlays
    /// - Parameters:
    ///   - analysis: Shot analysis results including accuracy and recommendations
    ///   - arView: PlatformARView to render into
    /// - Throws: ARRendererError if rendering fails
    func renderShotAnalysis(_ analysis: ShotAnalysis, in arView: PlatformARView) throws
    
    // MARK: - UI Elements
    
    /// Update HUD elements (scores, timers, etc.)
    /// - Parameters:
    ///   - elements: Array of HUD elements to display
    ///   - arView: PlatformARView containing the HUD
    /// - Throws: ARRendererError if HUD update fails
    func updateHUD(_ elements: [HUDElement], in arView: PlatformARView) throws
    
    /// Show temporary notification or alert
    /// - Parameters:
    ///   - notification: Notification content and style
    ///   - duration: How long to show (seconds)
    ///   - arView: PlatformARView to display in
    func showNotification(_ notification: ARNotification, duration: TimeInterval, in arView: PlatformARView)
    
    /// Hide all UI elements
    /// - Parameter arView: PlatformARView to clear
    func hideAllUI(in arView: PlatformARView)
    
    // MARK: - Lifecycle Management
    
    /// Initialize renderer with ARView
    /// - Parameter arView: PlatformARView to render into
    /// - Throws: ARRendererError if initialization fails
    func initialize(with arView: PlatformARView) throws    /// Cleanup renderer resources
    func cleanup()
    
    /// Pause rendering (but keep state)
    func pause()
    
    /// Resume rendering from paused state
    func resume()
    
    // MARK: - Visual Settings
    
    /// Update visual theme and colors
    /// - Parameter theme: New visual theme to apply
    /// - Throws: ARRendererError if theme application fails
    func applyTheme(_ theme: VisualTheme) throws
    
    /// Set opacity for all overlays
    /// - Parameter opacity: Opacity value (0.0 - 1.0)
    func setOverlayOpacity(_ opacity: Float)
    
    /// Enable or disable specific visual layers
    /// - Parameter layers: Dictionary of layer types and their enabled state
    func setLayerVisibility(_ layers: [RenderLayer: Bool])
    
    // MARK: - Performance
    
    /// Get current rendering performance metrics
    /// - Returns: Dictionary containing performance data
    func getPerformanceMetrics() -> [String: Double]
    
    /// Validate rendering meets performance requirements
    /// - Parameter requirements: Performance thresholds to check
    /// - Returns: True if requirements are met
    func meetsPerformanceRequirements(_ requirements: RenderingPerformanceRequirements) -> Bool
    
    /// Adjust rendering quality for performance
    /// - Parameter level: Quality level (0.0 = lowest, 1.0 = highest)
    func setQualityLevel(_ level: Float)
}

// MARK: - Configuration Types

/// Configuration for AR rendering systems
public struct ARRendererConfiguration {
    
    /// Visual settings for ball rendering
    public let ballVisuals: BallVisualSettings
    
    /// Trajectory visualization settings
    public let trajectoryVisuals: TrajectoryVisualSettings
    
    /// Cue guidance visualization settings
    public let cueGuidance: CueGuidanceSettings
    
    /// Table surface visualization
    public let tableVisuals: TableVisualSettings
    
    /// HUD configuration
    public let hudSettings: HUDSettings
    
    /// Performance settings
    public let performance: PerformanceSettings
    
    /// Animation settings
    public let animations: AnimationSettings
    
    public init(ballVisuals: BallVisualSettings = BallVisualSettings(),
                trajectoryVisuals: TrajectoryVisualSettings = TrajectoryVisualSettings(),
                cueGuidance: CueGuidanceSettings = CueGuidanceSettings(),
                tableVisuals: TableVisualSettings = TableVisualSettings(),
                hudSettings: HUDSettings = HUDSettings(),
                performance: PerformanceSettings = PerformanceSettings(),
                animations: AnimationSettings = AnimationSettings()) {
        self.ballVisuals = ballVisuals
        self.trajectoryVisuals = trajectoryVisuals
        self.cueGuidance = cueGuidance
        self.tableVisuals = tableVisuals
        self.hudSettings = hudSettings
        self.performance = performance
        self.animations = animations
    }
}

/// Visual settings for ball rendering
public struct BallVisualSettings {
    /// Show ball outlines/highlights
    public let showOutlines: Bool
    
    /// Outline thickness in pixels
    public let outlineThickness: Float
    
    /// Show ball numbers/labels
    public let showLabels: Bool
    
    /// Label font size
    public let labelFontSize: Float
    
    /// Ball highlight opacity
    public let highlightOpacity: Float
    
    /// Colors for different ball types
    public let colors: [BallColor: PlatformColor]
    
    /// Show confidence indicators
    public let showConfidence: Bool
    
    /// Render style for balls
    public let renderStyle: BallRenderStyle
    
    public init(showOutlines: Bool = true,
                outlineThickness: Float = 2.0,
                showLabels: Bool = true,
                labelFontSize: Float = 16.0,
                highlightOpacity: Float = 0.3,
                colors: [BallColor: PlatformColor] = [:],
                showConfidence: Bool = false,
                renderStyle: BallRenderStyle = .realistic) {
        self.showOutlines = showOutlines
        self.outlineThickness = outlineThickness
        self.showLabels = showLabels
        self.labelFontSize = labelFontSize
        self.highlightOpacity = highlightOpacity
        self.colors = colors
        self.showConfidence = showConfidence
        self.renderStyle = renderStyle
    }
}

/// Ball rendering styles
public enum BallRenderStyle: String, CaseIterable {
    case realistic = "realistic"       // 3D spheres with materials
    case outlined = "outlined"         // Simple outlines
    case highlighted = "highlighted"   // Glowing highlights
    case minimal = "minimal"          // Simple dots
}

/// Visual settings for trajectory rendering
public struct TrajectoryVisualSettings {
    /// Show predicted trajectories
    public let enabled: Bool
    
    /// Trajectory line thickness
    public let lineThickness: Float
    
    /// Trajectory color
    public let trajectoryColor: PlatformColor
    
    /// Show uncertainty bounds
    public let showUncertainty: Bool
    
    /// Uncertainty visualization style
    public let uncertaintyStyle: UncertaintyStyle
    
    /// Maximum trajectory length to show (seconds)
    public let maxTrajectoryLength: TimeInterval
    
    /// Number of trajectory segments for smoothness
    public let segmentCount: Int
    
    /// Fade trajectory over distance
    public let fadeWithDistance: Bool
    
    public init(enabled: Bool = true,
                lineThickness: Float = 3.0,
                trajectoryColor: PlatformColor = {
                    #if canImport(UIKit)
                    return UIColor.systemBlue
                    #elseif canImport(AppKit)
                    return NSColor.systemBlue
                    #else
                    return PlatformColor.blue
                    #endif
                }(),
                showUncertainty: Bool = true,
                uncertaintyStyle: UncertaintyStyle = .cone,
                maxTrajectoryLength: TimeInterval = 2.0,
                segmentCount: Int = 50,
                fadeWithDistance: Bool = true) {
        self.enabled = enabled
        self.lineThickness = lineThickness
        self.trajectoryColor = trajectoryColor
        self.showUncertainty = showUncertainty
        self.uncertaintyStyle = uncertaintyStyle
        self.maxTrajectoryLength = maxTrajectoryLength
        self.segmentCount = segmentCount
        self.fadeWithDistance = fadeWithDistance
    }
}

/// Uncertainty visualization styles
public enum UncertaintyStyle: String, CaseIterable {
    case cone = "cone"               // Expanding cone
    case tube = "tube"               // Cylindrical tube
    case particles = "particles"     // Particle cloud
    case ribbon = "ribbon"           // Flat ribbon
}

/// Cue guidance visualization settings
public struct CueGuidanceSettings {
    /// Show cue alignment assistance
    public let enabled: Bool
    
    /// Guidance line color
    public let guidelineColor: PlatformColor
    
    /// Show aim assist overlay
    public let showAimAssist: Bool
    
    /// Aim assist opacity
    public let aimAssistOpacity: Float
    
    /// Show power indicator
    public let showPowerIndicator: Bool
    
    /// Show angle measurements
    public let showAngleMeasurements: Bool
    
    /// Guidance line thickness
    public let guidelineThickness: Float
    
    /// Auto-hide guidance when not aiming
    public let autoHide: Bool
    
    public init(enabled: Bool = true,
                guidelineColor: PlatformColor = {
                    #if canImport(UIKit)
                    return UIColor.systemYellow
                    #elseif canImport(AppKit)
                    return NSColor.systemYellow
                    #else
                    return PlatformColor.yellow
                    #endif
                }(),
                showAimAssist: Bool = true,
                aimAssistOpacity: Float = 0.5,
                showPowerIndicator: Bool = true,
                showAngleMeasurements: Bool = false,
                guidelineThickness: Float = 2.0,
                autoHide: Bool = true) {
        self.enabled = enabled
        self.guidelineColor = guidelineColor
        self.showAimAssist = showAimAssist
        self.aimAssistOpacity = aimAssistOpacity
        self.showPowerIndicator = showPowerIndicator
        self.showAngleMeasurements = showAngleMeasurements
        self.guidelineThickness = guidelineThickness
        self.autoHide = autoHide
    }
}

/// Table surface visualization settings
public struct TableVisualSettings {
    /// Show detected table outline
    public let showTableOutline: Bool
    
    /// Table outline color
    public let outlineColor: PlatformColor
    
    /// Show pocket markers
    public let showPockets: Bool
    
    /// Pocket marker style
    public let pocketStyle: PocketStyle
    
    /// Show table grid for alignment
    public let showGrid: Bool
    
    /// Grid spacing in meters
    public let gridSpacing: Float
    
    /// Table surface opacity when highlighted
    public let surfaceOpacity: Float
    
    public init(showTableOutline: Bool = true,
                outlineColor: PlatformColor = {
                    #if canImport(UIKit)
                    return UIColor.systemGreen
                    #elseif canImport(AppKit)
                    return NSColor.systemGreen
                    #else
                    return PlatformColor.green
                    #endif
                }(),
                showPockets: Bool = true,
                pocketStyle: PocketStyle = .realistic,
                showGrid: Bool = false,
                gridSpacing: Float = 0.1,
                surfaceOpacity: Float = 0.1) {
        self.showTableOutline = showTableOutline
        self.outlineColor = outlineColor
        self.showPockets = showPockets
        self.pocketStyle = pocketStyle
        self.showGrid = showGrid
        self.gridSpacing = gridSpacing
        self.surfaceOpacity = surfaceOpacity
    }
}

/// Pocket visualization styles
public enum PocketStyle: String, CaseIterable {
    case realistic = "realistic"     // 3D pocket models
    case markers = "markers"         // Simple markers
    case highlighted = "highlighted" // Glowing circles
    case minimal = "minimal"         // Small dots
}

/// HUD configuration settings
public struct HUDSettings {
    /// Show HUD elements
    public let enabled: Bool
    
    /// HUD position on screen
    public let position: HUDPosition
    
    /// HUD opacity
    public let opacity: Float
    
    /// Auto-hide HUD during shots
    public let autoHide: Bool
    
    /// Elements to display
    public let enabledElements: Set<HUDElementType>
    
    /// Font settings
    public let fontSettings: FontSettings
    
    public init(enabled: Bool = true,
                position: HUDPosition = .topRight,
                opacity: Float = 0.9,
                autoHide: Bool = true,
                enabledElements: Set<HUDElementType> = [.score, .timer, .instructions],
                fontSettings: FontSettings = FontSettings()) {
        self.enabled = enabled
        self.position = position
        self.opacity = opacity
        self.autoHide = autoHide
        self.enabledElements = enabledElements
        self.fontSettings = fontSettings
    }
}

/// HUD position options
public enum HUDPosition: String, CaseIterable {
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case center = "center"
    case floating = "floating"
}

/// Performance settings for rendering
public struct PerformanceSettings {
    /// Target frame rate
    public let targetFrameRate: Int
    
    /// Maximum render quality (0.5 - 1.0)
    public let maxRenderQuality: Float
    
    /// Enable adaptive quality
    public let adaptiveQuality: Bool
    
    /// Maximum number of visible trajectory points
    public let maxTrajectoryPoints: Int
    
    /// Level of detail settings
    public let lodSettings: LODSettings
    
    /// GPU memory limit in MB
    public let maxGPUMemory: Float
    
    public init(targetFrameRate: Int = 60,
                maxRenderQuality: Float = 1.0,
                adaptiveQuality: Bool = true,
                maxTrajectoryPoints: Int = 1000,
                lodSettings: LODSettings = LODSettings(),
                maxGPUMemory: Float = 100.0) {
        self.targetFrameRate = targetFrameRate
        self.maxRenderQuality = maxRenderQuality
        self.adaptiveQuality = adaptiveQuality
        self.maxTrajectoryPoints = maxTrajectoryPoints
        self.lodSettings = lodSettings
        self.maxGPUMemory = maxGPUMemory
    }
}

/// Level of detail settings
public struct LODSettings {
    /// Distance thresholds for LOD levels
    public let distanceThresholds: [Float]
    
    /// Quality multipliers for each LOD level
    public let qualityLevels: [Float]
    
    /// Enable dynamic LOD based on performance
    public let dynamic: Bool
    
    public init(distanceThresholds: [Float] = [2.0, 5.0, 10.0],
                qualityLevels: [Float] = [1.0, 0.7, 0.4],
                dynamic: Bool = true) {
        self.distanceThresholds = distanceThresholds
        self.qualityLevels = qualityLevels
        self.dynamic = dynamic
    }
}

/// Animation configuration
public struct AnimationSettings {
    /// Enable smooth animations
    public let enabled: Bool
    
    /// Default animation duration
    public let defaultDuration: TimeInterval
    
    /// Animation easing curve
    public let easingCurve: AnimationCurve
    
    /// Enable particle effects
    public let enableParticles: Bool
    
    /// Animation quality level
    public let quality: AnimationQuality
    
    public init(enabled: Bool = true,
                defaultDuration: TimeInterval = 0.3,
                easingCurve: AnimationCurve = .easeInOut,
                enableParticles: Bool = true,
                quality: AnimationQuality = .high) {
        self.enabled = enabled
        self.defaultDuration = defaultDuration
        self.easingCurve = easingCurve
        self.enableParticles = enableParticles
        self.quality = quality
    }
}

/// Animation curve types
public enum AnimationCurve: String, CaseIterable {
    case linear = "linear"
    case easeIn = "easeIn"
    case easeOut = "easeOut"
    case easeInOut = "easeInOut"
    case bounce = "bounce"
    case spring = "spring"
}

/// Animation quality levels
public enum AnimationQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
}

// MARK: - Data Types

/// Rendering modes for different scenarios
public enum RenderingMode: String, CaseIterable {
    case training = "training"         // Full guidance and analysis
    case practice = "practice"         // Basic assistance
    case competition = "competition"   // Minimal overlays
    case analysis = "analysis"         // Post-shot analysis view
}

/// Render layers that can be toggled
public enum RenderLayer: String, CaseIterable {
    case balls = "balls"
    case trajectories = "trajectories"
    case cueGuidance = "cueGuidance"
    case table = "table"
    case hud = "hud"
    case annotations = "annotations"
    case effects = "effects"
}

/// Cue position and orientation
public struct CuePosition {
    /// Tip position in world coordinates
    public let tipPosition: simd_float3
    
    /// Cue orientation vector
    public let orientation: simd_float3
    
    /// Estimated power/velocity
    public let estimatedPower: Float
    
    /// Confidence in detection
    public let confidence: Float
    
    public init(tipPosition: simd_float3,
                orientation: simd_float3,
                estimatedPower: Float,
                confidence: Float) {
        self.tipPosition = tipPosition
        self.orientation = orientation
        self.estimatedPower = estimatedPower
        self.confidence = confidence
    }
}

/// Table geometry information
public struct TableGeometry {
    /// Table corners in world coordinates
    public let corners: [simd_float3]
    
    /// Table surface plane equation
    public let surfacePlane: simd_float4
    
    /// Pocket positions
    public let pockets: [PocketPosition]
    
    /// Table dimensions in meters
    public let dimensions: simd_float2
    
    /// Detection confidence
    public let confidence: Float
    
    public init(corners: [simd_float3],
                surfacePlane: simd_float4,
                pockets: [PocketPosition],
                dimensions: simd_float2,
                confidence: Float) {
        self.corners = corners
        self.surfacePlane = surfacePlane
        self.pockets = pockets
        self.dimensions = dimensions
        self.confidence = confidence
    }
}

/// Pocket position and type
public struct PocketPosition {
    /// 3D position in world coordinates
    public let position: simd_float3
    
    /// Pocket type (corner vs side)
    public let type: PocketType
    
    /// Pocket radius in meters
    public let radius: Float
    
    public init(position: simd_float3,
                type: PocketType,
                radius: Float = 0.06) { // Standard pocket radius
        self.position = position
        self.type = type
        self.radius = radius
    }
}

/// Types of pockets on a pool table
public enum PocketType: String, CaseIterable {
    case corner = "corner"
    case side = "side"
}

/// Shot analysis data for visualization
public struct ShotAnalysis {
    /// Shot trajectory that was taken
    public let actualTrajectory: [TrajectoryPoint]
    
    /// Predicted trajectory before shot
    public let predictedTrajectory: [TrajectoryPoint]
    
    /// Shot accuracy score (0.0 - 1.0)
    public let accuracy: Float
    
    /// Shot power assessment
    public let power: ShotPower
    
    /// Angle analysis
    public let angle: AngleAnalysis
    
    /// Shot outcome
    public let outcome: ShotOutcome
    
    /// Recommendations for improvement
    public let recommendations: [String]
    
    public init(actualTrajectory: [TrajectoryPoint],
                predictedTrajectory: [TrajectoryPoint],
                accuracy: Float,
                power: ShotPower,
                angle: AngleAnalysis,
                outcome: ShotOutcome,
                recommendations: [String]) {
        self.actualTrajectory = actualTrajectory
        self.predictedTrajectory = predictedTrajectory
        self.accuracy = accuracy
        self.power = power
        self.angle = angle
        self.outcome = outcome
        self.recommendations = recommendations
    }
}

/// Shot power assessment
public struct ShotPower {
    /// Actual power used (0.0 - 1.0)
    public let actual: Float
    
    /// Recommended power
    public let recommended: Float
    
    /// Power assessment
    public let assessment: PowerAssessment
    
    public init(actual: Float, recommended: Float, assessment: PowerAssessment) {
        self.actual = actual
        self.recommended = recommended
        self.assessment = assessment
    }
}

/// Power assessment categories
public enum PowerAssessment: String, CaseIterable {
    case tooWeak = "tooWeak"
    case perfect = "perfect"
    case tooStrong = "tooStrong"
}

/// Angle analysis data
public struct AngleAnalysis {
    /// Actual shot angle in radians
    public let actualAngle: Float
    
    /// Recommended angle
    public let recommendedAngle: Float
    
    /// Angle deviation
    public let deviation: Float
    
    /// Angle assessment
    public let assessment: AngleAssessment
    
    public init(actualAngle: Float, recommendedAngle: Float, deviation: Float, assessment: AngleAssessment) {
        self.actualAngle = actualAngle
        self.recommendedAngle = recommendedAngle
        self.deviation = deviation
        self.assessment = assessment
    }
}

/// Angle assessment categories
public enum AngleAssessment: String, CaseIterable {
    case perfect = "perfect"
    case slightlyOff = "slightlyOff"
    case significantDeviation = "significantDeviation"
}

/// Shot outcome types
public enum ShotOutcome: String, CaseIterable {
    case success = "success"           // Ball potted as intended
    case miss = "miss"                 // Ball missed target
    case scratch = "scratch"           // Cue ball potted
    case foul = "foul"                // Other foul committed
    case partialSuccess = "partialSuccess" // Some balls potted
}

/// HUD element types
public enum HUDElementType: String, CaseIterable {
    case score = "score"
    case timer = "timer"
    case instructions = "instructions"
    case ballCount = "ballCount"
    case accuracy = "accuracy"
    case power = "power"
    case angle = "angle"
}

/// HUD element data
public struct HUDElement {
    /// Element type
    public let type: HUDElementType
    
    /// Display text
    public let text: String
    
    /// Optional value for progress bars, etc.
    public let value: Float?
    
    /// Element color
    public let color: PlatformColor?
    
    public init(type: HUDElementType, text: String, value: Float? = nil, color: PlatformColor? = nil) {
        self.type = type
        self.text = text
        self.value = value
        self.color = color
    }
}

/// AR notification for temporary messages
public struct ARNotification {
    /// Notification text
    public let message: String
    
    /// Notification type affects styling
    public let type: NotificationType
    
    /// Optional icon
    public let icon: String?
    
    /// Text color
    public let color: PlatformColor?
    
    public init(message: String, type: NotificationType, icon: String? = nil, color: PlatformColor? = nil) {
        self.message = message
        self.type = type
        self.icon = icon
        self.color = color
    }
}

/// Notification types
public enum NotificationType: String, CaseIterable {
    case info = "info"
    case success = "success"
    case warning = "warning"
    case error = "error"
}

/// Visual theme configuration
public struct VisualTheme {
    /// Theme name
    public let name: String
    
    /// Primary color scheme
    public let primaryColors: PlatformColorScheme
    
    /// Secondary colors
    public let secondaryColors: PlatformColorScheme
    
    /// Background colors
    public let backgroundColors: PlatformColorScheme
    
    /// Text colors
    public let textColors: PlatformColorScheme
    
    public init(name: String,
                primaryColors: PlatformColorScheme,
                secondaryColors: PlatformColorScheme,
                backgroundColors: PlatformColorScheme,
                textColors: PlatformColorScheme) {
        self.name = name
        self.primaryColors = primaryColors
        self.secondaryColors = secondaryColors
        self.backgroundColors = backgroundColors
        self.textColors = textColors
    }
}

/// Color scheme for themes
public struct ColorScheme {
    /// Normal state color
    public let normal: PlatformColor
    
    /// Highlighted state color
    public let highlighted: PlatformColor
    
    /// Disabled state color
    public let disabled: PlatformColor
    
    public init(normal: PlatformColor, highlighted: PlatformColor, disabled: PlatformColor) {
        self.normal = normal
        self.highlighted = highlighted
        self.disabled = disabled
    }
}

/// Font settings for UI elements
public struct FontSettings {
    /// Font family name
    public let family: String
    
    /// Base font size
    public let size: Float
    
    /// Font weight
    public let weight: FontWeight
    
    public init(family: String = "SF Pro Display", size: Float = 16.0, weight: FontWeight = .regular) {
        self.family = family
        self.size = size
        self.weight = weight
    }
}

/// Font weight options
public enum FontWeight: String, CaseIterable {
    case light = "light"
    case regular = "regular"
    case medium = "medium"
    case bold = "bold"
}

/// Performance requirements for rendering validation
public struct RenderingPerformanceRequirements {
    /// Minimum frame rate (FPS)
    public let minimumFrameRate: Int
    
    /// Maximum frame time in milliseconds
    public let maximumFrameTime: TimeInterval
    
    /// Maximum GPU memory usage in MB
    public let maximumGPUMemory: Float
    
    /// Maximum draw calls per frame
    public let maximumDrawCalls: Int
    
    /// Maximum geometry complexity (vertices)
    public let maximumVertices: Int
    
    public init(minimumFrameRate: Int = 30,
                maximumFrameTime: TimeInterval = 33.0,
                maximumGPUMemory: Float = 200.0,
                maximumDrawCalls: Int = 100,
                maximumVertices: Int = 50000) {
        self.minimumFrameRate = minimumFrameRate
        self.maximumFrameTime = maximumFrameTime
        self.maximumGPUMemory = maximumGPUMemory
        self.maximumDrawCalls = maximumDrawCalls
        self.maximumVertices = maximumVertices
    }
}

// MARK: - Error Types

/// Errors that can occur during AR rendering
public enum ARRendererError: Error, LocalizedError, Equatable {
    case initializationFailed(String)
    case renderingFailed(String)
    case shaderCompilationFailed(String)
    case resourceLoadingFailed(String)
    case insufficientGPUMemory
    case unsupportedDevice
    case invalidConfiguration(String)
    case arSessionError(String)
    case themeApplicationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Renderer initialization failed: \(message)"
        case .renderingFailed(let message):
            return "Rendering operation failed: \(message)"
        case .shaderCompilationFailed(let message):
            return "Shader compilation failed: \(message)"
        case .resourceLoadingFailed(let message):
            return "Resource loading failed: \(message)"
        case .insufficientGPUMemory:
            return "Insufficient GPU memory for rendering operations"
        case .unsupportedDevice:
            return "Device does not support required rendering features"
        case .invalidConfiguration(let message):
            return "Invalid renderer configuration: \(message)"
        case .arSessionError(let message):
            return "AR session error: \(message)"
        case .themeApplicationFailed(let message):
            return "Theme application failed: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "Check device capabilities and rendering configuration"
        case .renderingFailed:
            return "Try reducing rendering quality or complexity"
        case .shaderCompilationFailed:
            return "Update device software or reduce shader complexity"
        case .resourceLoadingFailed:
            return "Check resource files and memory availability"
        case .insufficientGPUMemory:
            return "Reduce rendering quality or close other GPU-intensive apps"
        case .unsupportedDevice:
            return "Use a device with more advanced graphics capabilities"
        case .invalidConfiguration:
            return "Review and correct rendering configuration parameters"
        case .arSessionError:
            return "Restart AR session and ensure proper device permissions"
        case .themeApplicationFailed:
            return "Check theme configuration and resource availability"
        }
    }
}