import Foundation

extension BallColorAnalyzer.BallColor {
    /// Convert BallColor to EnhancedBallDetectionResult.BallType
    public var ballType: EnhancedBallDetectionResult.BallType {
        switch self.number {
        case 0:
            return .cueBall
        case 1...7:
            return .solid(self.number)
        case 8:
            return .eightBall
        case 9...15:
            return .stripe(self.number)
        default:
            return .unknown
        }
    }
}

extension BallColorResult {
    /// Determine ball type from color analysis
    public var ballType: EnhancedBallDetectionResult.BallType {
        guard let dominantColor = dominantColor, confidence > 0.5 else {
            return .unknown
        }
        return dominantColor.ballType
    }
}