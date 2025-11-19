import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @StateObject private var ballDetectionManager = BallDetectionManager()
    @State private var arView = ARView(frame: .zero)
    
    var body: some View {
        ZStack {
            ARViewContainer(arView: arView, ballDetectionManager: ballDetectionManager)
                .ignoresSafeArea()
            
            VStack {
                // Top UI
                HStack {
                    VStack(alignment: .leading) {
                        Text("CueDot")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        if ballDetectionManager.isTracking {
                            Text("Tracking Active")
                                .foregroundColor(.green)
                        } else {
                            Text("Not Tracking")
                                .foregroundColor(.red)
                        }
                        // Performance metrics
                        Text(String(format: "Avg ms: %.1f", ballDetectionManager.averageProcessingTimeMs))
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                        Text(String(format: "Last ms: %.1f", ballDetectionManager.lastFrameProcessingTimeMs))
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Balls Detected: \(ballDetectionManager.detectedBalls.count)")
                            .foregroundColor(.white)
                        
                        if ballDetectionManager.isGuidanceEnabled {
                            Text("Guidance: ON")
                                .foregroundColor(.green)
                        } else {
                            Text("Guidance: OFF")
                                .foregroundColor(.gray)
                        }
                        Text("Overlays: \(ballDetectionManager.overlayCount)")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if ballDetectionManager.isTracking {
                            ballDetectionManager.stopSession()
                        } else {
                            ballDetectionManager.startSession()
                        }
                    }) {
                        Text(ballDetectionManager.isTracking ? "Stop" : "Start")
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(ballDetectionManager.isTracking ? Color.red : Color.green)
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        ballDetectionManager.resetSession()
                    }) {
                        Text("Reset")
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        ballDetectionManager.startCalibration()
                    }) {
                        Text("Calibrate")
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        ballDetectionManager.toggleGuidance()
                    }) {
                        Image(systemName: ballDetectionManager.isGuidanceEnabled ? "eye" : "eye.slash")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(ballDetectionManager.isGuidanceEnabled ? Color.green : Color.gray)
                            .cornerRadius(25)
                    }

                    Button(action: {
                        ballDetectionManager.showCueCrosshair.toggle()
                    }) {
                        Image(systemName: ballDetectionManager.showCueCrosshair ? "plus.circle" : "plus.circle.fill")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(ballDetectionManager.showCueCrosshair ? Color.blue : Color.gray)
                            .cornerRadius(25)
                    }
                }
                .padding(.bottom, 50)

                // Confidence threshold slider
                VStack {
                    Text(String(format: "Overlay Confidence ≥ %.2f", ballDetectionManager.minimumOverlayConfidence))
                        .foregroundColor(.white)
                        .font(.caption)
                    Slider(value: Binding(get: {
                        Double(ballDetectionManager.minimumOverlayConfidence)
                    }, set: { newVal in
                        ballDetectionManager.minimumOverlayConfidence = Float(newVal)
                    }), in: 0.0...1.0, step: 0.05)
                        .tint(.green)
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let arView: ARView
    let ballDetectionManager: BallDetectionManager
    
    func makeUIView(context: Context) -> ARView {
        ballDetectionManager.setupAR(with: arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update UI if needed
    }
}

#Preview {
    ContentView()
}
