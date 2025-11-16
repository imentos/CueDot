# AR Cue Alignment Coach – MVP Specification

## 1. Overview
The AR Cue Alignment Coach replaces physical laser alignment devices and the Aramith Jim Rempe Training Ball by rendering a precise virtual center alignment aid on a real cue ball for junior learners practicing in a pool hall. The MVP focuses solely on real-time cue ball acquisition and overlay (single red dot + crosshair). No shot logging, calibration UI, or pattern selection yet.

## 2. User & Environment
- Primary User: Junior learner (beginner to early intermediate).
- Environment: Pool hall with stable overhead lighting (consistent top illumination, minimal glare baseline).
- Session Length Target: 15 minutes typical use per session.
- Space Constraints: No significant adjacent table interference assumed for MVP.
- Hall Restrictions: None (device stand allowed on table surface).

## 3. Goals & Non-Goals (MVP)
### Goals
- Accurate real-time visualization of cue ball center.
- Low-latency, high-frame-rate overlay to guide center strikes.
- Immediate occlusion/multi-ball warnings.

### Non-Goals (Deferred)
- Pattern selection (Rempe rings / hybrid).
- Spin tracking during/after shot.
- Shot logging, analytics, coach mode.
- Manual table corner calibration.
- Multi-user shared AR sessions.

## 4. Functional Requirements
### Cue Ball Detection
- Accuracy: Ideal ≤ 1 mm; Acceptable ≤ 3 mm (3D center error vs geometric center).
- Confidence Threshold: Render only if confidence ≥ 0.85; otherwise hide overlay.
- Latency (camera frame → overlay update): Ideal 25–30 ms; Max 55–60 ms.
- Frame Rate: Maintain 60 FPS target.
- Rotational Orientation (future patterns): Tolerance ideal ≤ 1°, max ≤ 3° (captured for roadmap; not visualized in MVP).
- Multi-ball Handling: If >1 white ball detected → show warning icon and suppress overlay.
- Occlusion Handling: On detected occlusion or confidence drop below threshold → hide overlay immediately and show warning icon.
- Scope: Pre-shot alignment only (no post-impact tracking / spin visualization).

### Overlay Design (Single Pattern)
- Pattern: Red center dot + crosshair.
- Dot Color: #FF0000.
- Dot Diameter: 6% of cue ball diameter (≈3.4 mm for 57 mm ball).
- Crosshair Arm Length: 22% of ball diameter in each direction from center (≈12.6 mm).
- Stroke Width: Adaptive ~2 px at ~1 m; scale with apparent ball size (screen space).
- Opacity: 0.9.
- Style: Camera-facing billboard anchored to ball center with small depth bias to avoid z-fighting.
- Animation: None (static); roadmap may add subtle pulse.
- Anti-Aliasing: Enable MSAA (SceneKit / Metal).

### Calibration & Tracking
- Table Calibration: Rely solely on ARKit plane detection (no manual corner marking in MVP).
- Re-calibration Triggers:
  - Tracking state limited/notAvailable > 2 s → attempt relight / internal recovery.
  - > 5 s degraded → hide overlay & show "Realign device" warning icon.
- Smoothing: Exponential Moving Average (EMA) α = 0.5 on 3D center.
- Jitter Handling: If frame-to-frame displacement > 2 mm for 3 consecutive frames → freeze center for next 5 frames (~83 ms) then resume smoothing.
- Limited Tracking Recovery: When tracking returns to normal for ≥ 0.5 s → fade overlay back in (fade duration 0.3 s applied when hiding).
- Prediction: None in MVP.

## 5. Edge Cases & Error Handling (Baseline)
| Case | MVP Behavior | Notes / Future Enhancement |
|------|--------------|----------------------------|
| Multiple white balls | Warning icon; hide overlay | Future: user tap to select ball |
| Occlusion (hand, cue) | Hide overlay; warning icon | Future: partial visibility threshold handling |
| Reflective glare | Rely on confidence; if drops, hide | Future: glare rejection / adaptive exposure |
| Motion blur | Confidence likely drops; hide | Future: blur metric to filter frames |
| Low light | Confidence may drop; hide | Future: raise ISO / local brightness mapping |
| Plane loss (device moved) | Tracking degraded triggers re-calibration logic | Future: plane re-estimation heuristics |

## 6. Performance & Metrics
- Target FPS: 60.
- CPU Budget (main thread): < 25%.
- GPU Budget: < 15%.
- Vision Model Memory: < 50 MB.
- Metrics Collection: Aggregate latency and confidence distribution every 10 s (in-memory only; no persistent per-frame logs).
- Debug Panel: Hidden (gesture, e.g., triple-tap) shows current confidence & latency real-time.

## 7. Privacy & Data Handling
- Camera Permission Rationale: "Used to detect the cue ball and display alignment guidance. Images never leave your device."
- Data Storage: No frames, photos, or videos saved.
- Analytics / Crash Reporting: None in MVP.
- Info Card: Not shown.

## 8. Architecture
### Module Overview
1. VisionDetector
   - Inputs: ARKit camera frame.
   - Outputs: { timestamp, ballCenter3D, confidence, occlusionFlag, multiBallFlag }
   - Implementation: Vision / CoreML (circle detection + color filter).
2. BallTracker
   - Inputs: VisionDetector output.
   - Logic: EMA smoothing, jitter freeze.
   - Outputs: { stabilizedCenter3D, jitterFlag, visible (bool) }
3. ARSessionManager
   - Inputs: ARKit session updates.
   - Outputs: { cameraTransform, trackingState }
4. OverlayRenderer
   - Inputs: stabilizedCenter3D, cameraTransform, visible.
   - Function: Renders crosshair/dot if visible & tracking normal.
5. WarningUIController
   - Events: occlusionFlag, multiBallFlag, trackingLost.
   - Output: Show/hide warning icon layer.
6. DebugPanelController
   - Inputs: rolling latency & confidence aggregates.
   - Output: Developer-only HUD (gesture triggered).

### Data Flow
Camera Frame → VisionDetector → BallTracker → OverlayRenderer.
Parallel: ARSessionManager provides tracking state & camera transform. WarningUIController listens to VisionDetector & ARSessionManager events.

### Key Algorithms
- EMA: filteredCenter = α * currentCenter + (1 - α) * previousFiltered.
- Jitter Detect: if |current - previousFiltered| > 2 mm for 3 frames → freeze (retain lastFiltered) for 5 frames.
- Latency Measurement: timestamp difference (frame capture vs render commit) aggregated.

## 9. Testing Strategy
### Unit Tests
- EMA smoothing correctness (stable input, jitter scenario).
- Jitter freeze logic (simulate displacement >2 mm).

### Offline Dataset
- Curated images with labeled ball centers (varied lighting & partial occlusion). Acceptance: ≥95% frames ≤3 mm error, ≥70% frames ≤1 mm error.

### Latency Harness
- Measure end-to-end; enforce mean < 35 ms, 95th percentile < 55 ms.

### Field Tests
- Real pool hall: confirm overlay hides promptly on occlusion, proper warning on second ball.

### Acceptance Summary
- Accuracy: 95% frames ≤ 3 mm, 70% ≤ 1 mm.
- Latency: mean < 35 ms; max (95th percentile) < 55 ms.
- Stability: No flicker (overlay hide/show) more than once per second under stable confidence ≥ 0.9.

## 10. Roadmap (Post-MVP)
- Pattern selection (center dot / full Rempe / hybrid).
- Spin tracking & post-shot alignment analysis.
- Shot logging + accuracy analytics dashboard.
- Coach mode (overlay guidance & remote review).
- Multi-user shared AR sessions.
- Advanced glare/motion blur mitigation.
- Surface-projected curved overlay lines.

## 11. Open Items / Decisions Needed (Pre-Implementation)
- Minimum iOS & device list (suggest iOS 17+, A15 chip or newer).
- Multi-ball selection heuristic (future): tap-to-select vs automatic proximity to cue tip.
- Glare & blur metrics: whether to integrate simple frame rejection early.
- Gesture for debug panel (triple-tap vs long-press).

## 12. Implementation Skeleton (Recommended)
```
/Source
  /AR
    ARSessionManager.swift
    OverlayRenderer.swift
  /Vision
    VisionDetector.swift
    BallTracker.swift
  /UI
    WarningUIController.swift
    DebugPanelController.swift
  /Core
    Models.swift (BallDetectionResult, TrackingState, etc.)
```

## 13. Risk Assessment & Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| Detection jitter at 60 FPS | Poor alignment guidance | EMA + jitter freeze already defined |
| Latency spikes on older devices | User perceives lag | Device gating; optimize Vision pipeline; early bail on low confidence |
| Plane loss due to device bump | Overlay disappears unexpectedly | Clear realign icon & fade logic |
| Reflective glare causing false positives | Misplaced center | Confidence gating + future glare rejection recipe |

## 14. Success Metrics (MVP Launch)
- Technical: Latency & accuracy thresholds met.
- Usability: User can consistently align within perceived center (qualitative feedback).
- Reliability: <1 unintended overlay flicker per minute in stable conditions.

---
End of MVP Specification.
