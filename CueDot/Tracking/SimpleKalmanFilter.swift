import Foundation
import simd

/// Simple 3D position tracking with velocity estimation using Kalman filtering
/// State: [x, y, z, vx, vy, vz] - position and velocity
public class SimpleKalmanFilter {
    
    // MARK: - State Variables
    
    /// 6D state vector: [x, y, z, vx, vy, vz]
    private var state: [Float] = Array(repeating: 0, count: 6)
    
    /// 6x6 covariance matrix (stored as flat array for simplicity)
    private var covariance: [Float] = Array(repeating: 0, count: 36)
    
    /// Process noise parameter
    private let processNoise: Float
    
    /// Measurement noise parameter  
    private let measurementNoise: Float
    
    /// Last update timestamp
    private var lastTimestamp: TimeInterval?
    
    /// Track confidence
    private var confidence: Float = 0.0
    
    // MARK: - Initialization
    
    public init(initialPosition: simd_float3, 
                processNoise: Float = 0.1,
                measurementNoise: Float = 0.5) {
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
        
        // Initialize state with position, zero velocity
        state[0] = initialPosition.x
        state[1] = initialPosition.y
        state[2] = initialPosition.z
        state[3] = 0 // vx
        state[4] = 0 // vy
        state[5] = 0 // vz
        
        // Initialize covariance matrix as identity scaled by process noise
        for i in 0..<6 {
            covariance[i * 6 + i] = processNoise * 10
        }
        
        confidence = 0.1
    }
    
    // MARK: - Public Interface
    
    /// Get current position estimate
    public func getPosition() -> simd_float3 {
        return simd_float3(state[0], state[1], state[2])
    }
    
    /// Get current velocity estimate
    public func getVelocity() -> simd_float3 {
        return simd_float3(state[3], state[4], state[5])
    }
    
    /// Get position uncertainty (diagonal elements of position covariance)
    public func getPositionUncertainty() -> simd_float3 {
        return simd_float3(
            sqrt(covariance[0]),  // x uncertainty
            sqrt(covariance[7]),  // y uncertainty 
            sqrt(covariance[14])  // z uncertainty
        )
    }
    
    /// Get tracking confidence [0,1]
    public func getTrackingConfidence() -> Float {
        return confidence
    }
    
    /// Predict position at given timestamp
    public func predict(at timestamp: TimeInterval) -> simd_float3 {
        if let lastTime = lastTimestamp {
            let dt = Float(timestamp - lastTime)
            
            // Simple prediction: position + velocity * dt
            let predictedX = state[0] + state[3] * dt
            let predictedY = state[1] + state[4] * dt
            let predictedZ = state[2] + state[5] * dt
            
            return simd_float3(predictedX, predictedY, predictedZ)
        }
        
        return getPosition()
    }
    
    /// Update filter with new measurement
    public func update(with measurement: simd_float3, 
                      at timestamp: TimeInterval,
                      confidence measurementConfidence: Float = 1.0) {
        
        // Prediction step
        if let lastTime = lastTimestamp {
            let dt = Float(timestamp - lastTime)
            predict(deltaTime: dt)
        }
        
        // Update step
        updateWithMeasurement(measurement, confidence: measurementConfidence)
        
        lastTimestamp = timestamp
        
        // Update confidence based on measurement quality
        self.confidence = min(1.0, self.confidence + measurementConfidence * 0.1)
    }
    
    /// Reset filter to new position
    public func reset(to position: simd_float3) {
        state[0] = position.x
        state[1] = position.y
        state[2] = position.z
        state[3] = 0
        state[4] = 0
        state[5] = 0
        
        // Reset covariance
        for i in 0..<36 {
            covariance[i] = 0
        }
        for i in 0..<6 {
            covariance[i * 6 + i] = processNoise * 10
        }
        
        confidence = 0.1
        lastTimestamp = nil
    }
    
    /// Calculate acceleration (simple finite difference)
    public func getAcceleration(previousVelocity: simd_float3) -> simd_float3 {
        let currentVelocity = getVelocity()
        return currentVelocity - previousVelocity
    }
    
    // MARK: - Private Methods
    
    private func predict(deltaTime dt: Float) {
        // State transition: position += velocity * dt
        state[0] += state[3] * dt
        state[1] += state[4] * dt
        state[2] += state[5] * dt
        // Velocity remains the same (constant velocity model)
        
        // Increase uncertainty due to process noise
        addProcessNoise(dt: dt)
        
        // Decay confidence over time
        confidence *= 0.99
    }
    
    private func updateWithMeasurement(_ measurement: simd_float3, confidence: Float) {
        // Innovation (measurement residual)
        let innovation = [
            measurement.x - state[0],
            measurement.y - state[1], 
            measurement.z - state[2]
        ]
        
        // Innovation covariance (simplified)
        let measurementVar = measurementNoise / max(0.01, confidence)
        let innovationCovariance = [
            covariance[0] + measurementVar,  // x
            covariance[7] + measurementVar,  // y
            covariance[14] + measurementVar  // z
        ]
        
        // Kalman gain (simplified for position measurements)
        let gain = [
            covariance[0] / innovationCovariance[0],
            covariance[7] / innovationCovariance[1],
            covariance[14] / innovationCovariance[2]
        ]
        
        // Update state
        state[0] += gain[0] * innovation[0]
        state[1] += gain[1] * innovation[1]
        state[2] += gain[2] * innovation[2]
        
        // Update velocity based on innovation (simple approach)
        if lastTimestamp != nil {
            let dt = Float(0.033) // Assume ~30fps for velocity estimation
            if dt > 0 {
                state[3] += gain[0] * innovation[0] / dt * 0.1 // Small velocity update
                state[4] += gain[1] * innovation[1] / dt * 0.1
                state[5] += gain[2] * innovation[2] / dt * 0.1
            }
        }
        
        // Update covariance (simplified Joseph form)
        covariance[0] *= (1 - gain[0])   // x variance
        covariance[7] *= (1 - gain[1])   // y variance
        covariance[14] *= (1 - gain[2])  // z variance
        
        // Clamp variance to reasonable bounds
        covariance[0] = max(0.001, min(10.0, covariance[0]))
        covariance[7] = max(0.001, min(10.0, covariance[7]))
        covariance[14] = max(0.001, min(10.0, covariance[14]))
    }
    
    private func addProcessNoise(dt: Float) {
        // Add process noise to position and velocity
        let positionNoise = processNoise * dt * dt * 0.5
        let velocityNoise = processNoise * dt
        
        covariance[0] += positionNoise   // x
        covariance[7] += positionNoise   // y
        covariance[14] += positionNoise  // z
        covariance[21] += velocityNoise  // vx
        covariance[28] += velocityNoise  // vy
        covariance[35] += velocityNoise  // vz
    }
}

// MARK: - Convenience Extensions

extension SimpleKalmanFilter {
    /// Quick setup for typical ball tracking
    public static func ballTracker(initialPosition: simd_float3) -> SimpleKalmanFilter {
        return SimpleKalmanFilter(
            initialPosition: initialPosition,
            processNoise: 0.05,     // Low process noise for smooth tracking
            measurementNoise: 0.3   // Higher measurement noise for vision uncertainty
        )
    }
}