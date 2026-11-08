import XCTest
@testable import MagicMousePadCore

final class GestureRecognizerTests: XCTestCase {
    private var recognizer: GestureRecognizer!
    private var fired: [MouseGesture] = []

    override func setUp() {
        recognizer = GestureRecognizer()
        fired = []
        recognizer.onGesture = { [unowned self] in self.fired.append($0) }
    }

    /// Moves `fingers` together from `start` by (dx, dy) normalized units over `duration`.
    private func drag(fingers: Int, start: (Double, Double), dx: Double, dy: Double,
                      duration: Double = 0.2, t0: Double = 0, spread: Double = 0.18) {
        let steps = 20
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let pts = (0..<fingers).map { n in
                TouchPoint(id: Int32(n + 1),
                           x: start.0 + Double(n) * spread + dx * f,
                           y: start.1 + dy * f)
            }
            recognizer.process(pts, at: t0 + duration * f)
        }
        recognizer.process([], at: t0 + duration + 0.01)
    }

    func testTwoFingerSwipeLeft() {
        drag(fingers: 2, start: (0.5, 0.5), dx: -0.4, dy: 0)
        XCTAssertEqual(fired, [.twoFingerSwipeLeft])
    }

    func testTwoFingerSwipeRight() {
        drag(fingers: 2, start: (0.1, 0.5), dx: 0.4, dy: 0)
        XCTAssertEqual(fired, [.twoFingerSwipeRight])
    }

    func testTwoFingerSwipeUpAndDown() {
        drag(fingers: 2, start: (0.3, 0.3), dx: 0, dy: 0.3)
        drag(fingers: 2, start: (0.3, 0.7), dx: 0, dy: -0.3, t0: 1)
        XCTAssertEqual(fired, [.twoFingerSwipeUp, .twoFingerSwipeDown])
    }

    func testInvertVertical() {
        recognizer.config.invertVertical = true
        drag(fingers: 2, start: (0.3, 0.3), dx: 0, dy: 0.3)
        XCTAssertEqual(fired, [.twoFingerSwipeDown])
    }

    func testThreeFingerSwipe() {
        drag(fingers: 3, start: (0.1, 0.5), dx: 0.4, dy: 0, spread: 0.15)
        XCTAssertEqual(fired, [.threeFingerSwipeRight])
    }

    func testOnlyOneGesturePerWindow() {
        drag(fingers: 2, start: (0.1, 0.5), dx: 0.8, dy: 0, duration: 0.4)
        XCTAssertEqual(fired.count, 1)
    }

    func testSingleFingerDoesNothing() {
        let steps = 10
        for i in 0...steps {
            recognizer.process([TouchPoint(id: 1, x: 0.1 + 0.08 * Double(i), y: 0.5)], at: Double(i) * 0.02)
        }
        recognizer.process([], at: 1)
        XCTAssertTrue(fired.isEmpty)
    }

    func testSlowDriftIsIgnored() {
        // 0.4 normalized over 4 seconds — resting fingers drifting, not a swipe.
        drag(fingers: 2, start: (0.1, 0.5), dx: 0.4, dy: 0, duration: 4)
        XCTAssertTrue(fired.isEmpty)
    }

    func testTwoFingerTap() {
        let pts = [TouchPoint(id: 1, x: 0.3, y: 0.5), TouchPoint(id: 2, x: 0.6, y: 0.5)]
        recognizer.process(pts, at: 0)
        recognizer.process(pts, at: 0.1)
        recognizer.process([], at: 0.15)
        XCTAssertEqual(fired, [.twoFingerTap])
    }

    func testTapWithRestingFinger() {
        let rest = TouchPoint(id: 1, x: 0.3, y: 0.5)
        recognizer.process([rest], at: 0)
        recognizer.process([rest], at: 2)
        let extra = [rest, TouchPoint(id: 2, x: 0.5, y: 0.5), TouchPoint(id: 3, x: 0.7, y: 0.5)]
        recognizer.process(extra, at: 2.05)
        recognizer.process(extra, at: 2.15)
        recognizer.process([rest], at: 2.2)
        XCTAssertEqual(fired, [.threeFingerTap])
    }

    func testClickCancelsTap() {
        let pts = [TouchPoint(id: 1, x: 0.3, y: 0.5), TouchPoint(id: 2, x: 0.6, y: 0.5)]
        recognizer.process(pts, at: 0)
        recognizer.noteClick()
        recognizer.process([], at: 0.1)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLongHoldIsNotATap() {
        let pts = [TouchPoint(id: 1, x: 0.3, y: 0.5), TouchPoint(id: 2, x: 0.6, y: 0.5)]
        recognizer.process(pts, at: 0)
        recognizer.process(pts, at: 0.8)
        recognizer.process([], at: 0.9)
        XCTAssertTrue(fired.isEmpty)
    }

    func testPinchOutAndIn() {
        func pinch(from: Double, to: Double, t0: Double) {
            for i in 0...10 {
                let f = Double(i) / 10
                let half = (from + (to - from) * f) / 2
                recognizer.process([TouchPoint(id: 1, x: 0.5 - half, y: 0.5),
                                    TouchPoint(id: 2, x: 0.5 + half, y: 0.5)], at: t0 + f * 0.2)
            }
            recognizer.process([], at: t0 + 0.3)
        }
        pinch(from: 0.3, to: 0.7, t0: 0)
        pinch(from: 0.7, to: 0.3, t0: 1)
        XCTAssertEqual(fired, [.pinchOut, .pinchIn])
    }

    func testOneFingerTap() {
        recognizer.process([TouchPoint(id: 1, x: 0.5, y: 0.6)], at: 0)
        recognizer.process([TouchPoint(id: 1, x: 0.5, y: 0.6)], at: 0.08)
        recognizer.process([], at: 0.12)
        XCTAssertEqual(fired, [.oneFingerTap])
    }

    func testOneFingerTapIgnoresRestingAndClicks() {
        // Held too long
        recognizer.process([TouchPoint(id: 1, x: 0.5, y: 0.6)], at: 0)
        recognizer.process([], at: 0.5)
        // Physical click
        recognizer.process([TouchPoint(id: 2, x: 0.5, y: 0.6)], at: 1)
        recognizer.noteClick()
        recognizer.process([], at: 1.1)
        // Slid across the surface
        recognizer.process([TouchPoint(id: 3, x: 0.3, y: 0.6)], at: 2)
        recognizer.process([TouchPoint(id: 3, x: 0.5, y: 0.6)], at: 2.05)
        recognizer.process([], at: 2.1)
        XCTAssertTrue(fired.isEmpty)
    }

    func testTwoFingerTapDoesNotAlsoFireOneFingerTap() {
        let pts = [TouchPoint(id: 1, x: 0.3, y: 0.5), TouchPoint(id: 2, x: 0.6, y: 0.5)]
        recognizer.process([pts[0]], at: 0)
        recognizer.process(pts, at: 0.02)
        recognizer.process([pts[0]], at: 0.1)
        recognizer.process([], at: 0.12)
        XCTAssertEqual(fired, [.twoFingerTap])
    }

    func testTrackpadProfileMatchesThisMacsSettings() {
        let prefs: [String: Int] = ["Clicking": 1, "TrackpadRightClick": 1, "TrackpadPinch": 1,
                                    "TrackpadThreeFingerHorizSwipeGesture": 2, "TrackpadThreeFingerVertSwipeGesture": 2,
                                    "TrackpadThreeFingerTapGesture": 0]
        let m = TrackpadProfile.from(value: { prefs[$0] }, swipeNavigateWithScrolls: nil).mapping
        XCTAssertEqual(m[.oneFingerTap], .click)
        XCTAssertEqual(m[.twoFingerTap], .secondaryClick)
        XCTAssertEqual(m[.twoFingerSwipeRight], .back)
        XCTAssertEqual(m[.twoFingerSwipeUp], ActionKind.none, "two fingers up/down must stay free for scrolling")
        XCTAssertEqual(m[.pinchOut], .zoomIn)
        XCTAssertEqual(m[.threeFingerSwipeLeft], .nextSpace)
        XCTAssertEqual(m[.threeFingerSwipeUp], .missionControl)
        XCTAssertEqual(m[.threeFingerSwipeDown], .appExpose)
        XCTAssertEqual(m[.threeFingerTap], ActionKind.none)
    }

    func testFactoryTrackpadHasNoTapToClick() {
        XCTAssertEqual(TrackpadProfile.factory.mapping[.oneFingerTap], ActionKind.none)
        XCTAssertEqual(TrackpadProfile.factory.mapping[.threeFingerSwipeLeft], .nextSpace) // from 4-finger default
    }

    func testSensitivityMapping() {
        XCTAssertEqual(RecognizerConfig.swipeDistance(forSensitivity: 0), 20)
        XCTAssertEqual(RecognizerConfig.swipeDistance(forSensitivity: 1), 6)
    }

    func testDefaultMappingCoversEveryGesture() {
        for g in MouseGesture.allCases {
            XCTAssertNotNil(DefaultMapping.mapping[g], "missing default for \(g)")
        }
    }
}
