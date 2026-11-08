import Foundation

/// One finger currently in contact with the surface.
public struct TouchPoint: Equatable, Sendable {
    public var id: Int32
    /// Normalized 0…1, left → right.
    public var x: Double
    /// Normalized 0…1, back (palm side) → front (cable/tip side).
    public var y: Double

    public init(id: Int32, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

public struct RecognizerConfig: Equatable, Sendable {
    /// Physical size of the touch surface, used to compare movement in millimetres.
    public var surfaceWidthMM: Double = 51.5
    public var surfaceHeightMM: Double = 90.5

    /// Distance the fingers must travel together to count as a swipe.
    public var swipeDistanceMM: Double = 13
    /// The movement has to happen within this time (filters slow drift of resting fingers).
    public var swipeWindow: TimeInterval = 0.75
    /// How much one axis must dominate the other for a swipe to register.
    public var directionDominance: Double = 1.3

    /// Relative change of finger spread that counts as a pinch (0.35 = 35 %).
    public var pinchRatio: Double = 0.35

    /// A tap is a quick touch-and-lift with almost no movement.
    public var tapMaxDuration: TimeInterval = 0.25
    public var tapMaxMovementMM: Double = 3

    /// Flip the up/down direction.
    public var invertVertical: Bool = false

    public init() {}

    /// Maps a 0…1 sensitivity slider to a swipe distance (higher = shorter swipe).
    public static func swipeDistance(forSensitivity s: Double) -> Double {
        let clamped = min(max(s, 0), 1)
        return 20 - clamped * 14 // 20 mm … 6 mm
    }
}

/// Turns a stream of touch frames into discrete gestures.
///
/// A *gesture window* opens when two or more fingers are on the surface and
/// closes when fewer than two remain, so a resting index finger never blocks
/// a gesture. At most one gesture fires per window.
public final class GestureRecognizer {
    public var config: RecognizerConfig
    public var onGesture: ((MouseGesture) -> Void)?

    public private(set) var fingerCount = 0

    // Window state
    private var inWindow = false
    private var windowStart: TimeInterval = 0
    private var windowPeak = 0
    private var windowFired = false
    private var windowClicked = false
    private var windowOrigin: [Int32: TouchPoint] = [:]
    private var windowMaxMovement: Double = 0

    // Phase state (stable finger count)
    private var phaseCount = 0
    private var phaseStart: TimeInterval = 0
    private var phaseAnchor: [Int32: TouchPoint] = [:]

    public init(config: RecognizerConfig = RecognizerConfig()) {
        self.config = config
    }

    /// Call when a physical click happens; a click cancels any tap in progress.
    public func noteClick() {
        if inWindow { windowClicked = true }
    }

    public func reset() {
        fingerCount = 0
        inWindow = false
        phaseCount = 0
        phaseAnchor = [:]
        windowOrigin = [:]
    }

    /// Feed one frame of active contacts (fingers actually touching).
    public func process(_ touches: [TouchPoint], at time: TimeInterval) {
        let count = touches.count
        fingerCount = count

        if count >= 2 {
            if !inWindow { openWindow(at: time) }
            windowPeak = max(windowPeak, count)
            for t in touches {
                let origin = windowOrigin[t.id] ?? t
                windowOrigin[t.id] = origin
                windowMaxMovement = max(windowMaxMovement, distanceMM(origin, t))
            }
        }

        if count != phaseCount || !sameFingers(touches) {
            beginPhase(touches, at: time)
        } else if count >= 2 && inWindow && !windowFired {
            if time - phaseStart > config.swipeWindow {
                beginPhase(touches, at: time) // too slow — re-anchor
            } else {
                evaluateMotion(touches)
            }
        }

        if count < 2 && inWindow { closeWindow(at: time) }
    }

    // MARK: - Private

    private func openWindow(at time: TimeInterval) {
        inWindow = true
        windowStart = time
        windowPeak = 0
        windowFired = false
        windowClicked = false
        windowOrigin = [:]
        windowMaxMovement = 0
    }

    private func closeWindow(at time: TimeInterval) {
        defer { inWindow = false }
        guard !windowFired, !windowClicked else { return }
        guard time - windowStart <= config.tapMaxDuration else { return }
        guard windowMaxMovement <= config.tapMaxMovementMM else { return }
        if let tap = MouseGesture.tap(fingers: windowPeak) { fire(tap) }
    }

    private func beginPhase(_ touches: [TouchPoint], at time: TimeInterval) {
        phaseCount = touches.count
        phaseStart = time
        phaseAnchor = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0) })
    }

    private func sameFingers(_ touches: [TouchPoint]) -> Bool {
        touches.allSatisfy { phaseAnchor[$0.id] != nil }
    }

    private func evaluateMotion(_ touches: [TouchPoint]) {
        let count = touches.count

        // Mean displacement in millimetres.
        var dx = 0.0, dy = 0.0
        for t in touches {
            guard let a = phaseAnchor[t.id] else { continue }
            dx += (t.x - a.x) * config.surfaceWidthMM
            dy += (t.y - a.y) * config.surfaceHeightMM
        }
        dx /= Double(count)
        dy /= Double(count)
        if config.invertVertical { dy = -dy }

        // Pinch: two fingers moving apart / together while the centre stays put.
        if count == 2, let a0 = phaseAnchor[touches[0].id], let b0 = phaseAnchor[touches[1].id] {
            let before = distanceMM(a0, b0)
            let now = distanceMM(touches[0], touches[1])
            let centroidMove = (dx * dx + dy * dy).squareRoot()
            if before > 6, centroidMove < config.swipeDistanceMM * 0.6 {
                let ratio = now / before
                if ratio >= 1 + config.pinchRatio { return fire(.pinchOut) }
                if ratio <= 1 / (1 + config.pinchRatio) { return fire(.pinchIn) }
            }
        }

        let ax = abs(dx), ay = abs(dy)
        guard max(ax, ay) >= config.swipeDistanceMM else { return }

        let direction: MouseGesture.Direction
        if ax >= ay * config.directionDominance {
            direction = dx < 0 ? .left : .right
        } else if ay >= ax * config.directionDominance {
            direction = dy > 0 ? .up : .down
        } else {
            return // diagonal — wait for a clearer direction
        }
        if let g = MouseGesture.swipe(fingers: count, direction: direction) { fire(g) }
    }

    private func fire(_ gesture: MouseGesture) {
        windowFired = true
        onGesture?(gesture)
    }

    private func distanceMM(_ a: TouchPoint, _ b: TouchPoint) -> Double {
        let dx = (a.x - b.x) * config.surfaceWidthMM
        let dy = (a.y - b.y) * config.surfaceHeightMM
        return (dx * dx + dy * dy).squareRoot()
    }
}
