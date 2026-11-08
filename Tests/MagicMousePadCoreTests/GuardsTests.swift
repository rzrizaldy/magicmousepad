import XCTest
@testable import MagicMousePadCore

final class GuardsTests: XCTestCase {
    func testPointerGuardDetectsMovementAndForgets() {
        var guardian = PointerMotionGuard()
        XCTAssertFalse(guardian.isMoving(at: 0))
        guardian.record(dx: 1, dy: 0, at: 0.00) // a tap's tiny jitter
        XCTAssertFalse(guardian.isMoving(at: 0.01))
        for i in 0..<5 { guardian.record(dx: 3, dy: 0, at: 0.02 + Double(i) * 0.01) }
        XCTAssertTrue(guardian.isMoving(at: 0.08))
        XCTAssertFalse(guardian.isMoving(at: 1.0), "movement older than the window is forgotten")
    }

    func testBatteryReminderFiresOncePerDischarge() {
        var r = BatteryReminder()
        XCTAssertNil(r.update(percent: 80))
        XCTAssertEqual(r.update(percent: 15), .low(15))
        XCTAssertNil(r.update(percent: 14))
        XCTAssertNil(r.update(percent: 10))
        XCTAssertEqual(r.update(percent: 5), .critical(5))
        XCTAssertNil(r.update(percent: 4))
        XCTAssertNil(r.update(percent: 100)) // charged → re-armed
        XCTAssertEqual(r.update(percent: 12), .low(12))
    }

    func testBatteryReminderJumpsStraightToCritical() {
        var r = BatteryReminder()
        XCTAssertEqual(r.update(percent: 3), .critical(3))
        XCTAssertNil(r.update(percent: 3))
    }

    func testScrollAdjustment() {
        XCTAssertTrue(ScrollAdjustment().isIdentity)
        let reversed = ScrollAdjustment(reverse: true, speed: 1)
        XCTAssertEqual(reversed.scaleLines(3), -3)
        let slow = ScrollAdjustment(reverse: false, speed: 0.5)
        XCTAssertEqual(slow.scaleLines(1), 1, "slow scrolling never rounds to zero")
        XCTAssertEqual(slow.scaleLines(-1), -1)
        XCTAssertEqual(ScrollAdjustment(reverse: true, speed: 0.5).scaleLines(1), -1)
        XCTAssertEqual(ScrollAdjustment(speed: 2).scaleLines(4), 8)
    }
}
