import Foundation

/// Remembers recent pointer movement so a tap made while gripping or moving
/// the mouse is never mistaken for a deliberate click.
public struct PointerMotionGuard: Sendable {
    /// How far back to look.
    public var window: TimeInterval = 0.3
    /// Pointer travel (points) within `window` that counts as "moving the mouse".
    public var threshold: Double = 6

    private var samples: [(time: TimeInterval, distance: Double)] = []

    public init() {}

    public mutating func record(dx: Double, dy: Double, at time: TimeInterval) {
        samples.append((time, (dx * dx + dy * dy).squareRoot()))
        prune(now: time)
    }

    public mutating func isMoving(at time: TimeInterval) -> Bool {
        prune(now: time)
        return samples.reduce(0) { $0 + $1.distance } >= threshold
    }

    private mutating func prune(now: TimeInterval) {
        samples.removeAll { now - $0.time > window }
    }
}

/// Decides when to remind the user to charge. The Magic Mouse charges from underneath,
/// so the reminder comes early enough to charge it while you're away.
public struct BatteryReminder: Sendable {
    public enum Alert: Equatable, Sendable { case low(Int), critical(Int) }

    public var lowThreshold = 15
    public var criticalThreshold = 5
    /// Re-arm once the battery climbs back above this (i.e. after charging).
    public var rearmThreshold = 30

    private var sentLow = false
    private var sentCritical = false

    public init() {}

    public mutating func update(percent: Int) -> Alert? {
        if percent >= rearmThreshold {
            sentLow = false
            sentCritical = false
            return nil
        }
        if percent <= criticalThreshold, !sentCritical {
            sentCritical = true
            sentLow = true
            return .critical(percent)
        }
        if percent <= lowThreshold, !sentLow {
            sentLow = true
            return .low(percent)
        }
        return nil
    }
}

/// Per-device scroll adjustments for the Magic Mouse (macOS applies one direction to every device).
public struct ScrollAdjustment: Equatable, Sendable {
    public var reverse = false
    /// 0.5 … 2.0
    public var speed = 1.0

    public init(reverse: Bool = false, speed: Double = 1.0) {
        self.reverse = reverse
        self.speed = speed
    }

    public var isIdentity: Bool { !reverse && abs(speed - 1) < 0.001 }

    /// Factor every scroll delta is multiplied by.
    public var factor: Double { (reverse ? -1 : 1) * min(max(speed, 0.25), 3) }

    /// Integer line deltas must not round a slow scroll down to zero.
    public func scaleLines(_ value: Int64) -> Int64 {
        guard value != 0 else { return 0 }
        let scaled = (Double(value) * factor).rounded()
        if scaled == 0 { return factor < 0 ? -value.signum() : value.signum() }
        return Int64(scaled)
    }
}
