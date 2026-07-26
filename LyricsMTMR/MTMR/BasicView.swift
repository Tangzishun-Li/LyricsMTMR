//
//  BasicView.swift
//  MTMR
//
//  Created by Fedor Zaitsev on 3/29/20.
//  Copyright © 2020 Anton Palgunov. All rights reserved.
//

import Foundation

// MARK: - Swipe Direction
enum SwipeDirection {
    case left, right, up, down, unknown

    var isVertical: Bool {
        return self == .up || self == .down
    }

    var isHorizontal: Bool {
        return self == .left || self == .right
    }

    var description: String {
        switch self {
        case .left: return "left"
        case .right: return "right"
        case .up: return "up"
        case .down: return "down"
        case .unknown: return "unknown"
        }
    }
}

// MARK: - Swipe Record (for double-swipe detection)
struct SwipeRecord {
    let direction: SwipeDirection
    let fingers: Int
    let timestamp: TimeInterval
}

// MARK: - BasicView
class BasicView: NSCustomTouchBarItem, NSGestureRecognizerDelegate {
    var twofingers: NSPanGestureRecognizer!
    var threefingers: NSPanGestureRecognizer!
    var fourfingers: NSPanGestureRecognizer!
    var swipeItems: [SwipeItem] = []

    // Horizontal start positions (original)
    var prevPositions: [Int: CGFloat] = [2:0, 3:0, 4:0]
    // Vertical start positions (new)
    var prevYPositions: [Int: CGFloat] = [2:0, 3:0, 4:0]

    // Legacy gesture positions (volume/brightness step)
    var legacyPrevPositions: [Int: CGFloat] = [2:0, 3:0, 4:0]
    var legacyGesturesEnabled = false

    // MARK: - Double Swipe Detection (new)
    var firstSwipe: SwipeRecord? = nil
    let doubleSwipeTimeThreshold: TimeInterval = 0.6

    // MARK: - Angle Thresholds (new)
    let horizontalAngleMax: CGFloat = 30.0
    let verticalAngleMin: CGFloat = 60.0

    init(identifier: NSTouchBarItem.Identifier, items: [NSTouchBarItem], swipeItems: [SwipeItem]) {
        super.init(identifier: identifier)
        self.swipeItems = swipeItems
        let views = items.compactMap { $0.view }
        let stackView = NSStackView(views: views)
        stackView.spacing = 8
        stackView.orientation = .horizontal
        view = stackView

        twofingers = NSPanGestureRecognizer(target: self, action: #selector(twofingersHandler(_:)))
        twofingers.numberOfTouchesRequired = 2
        twofingers.allowedTouchTypes = .direct
        view.addGestureRecognizer(twofingers)

        threefingers = NSPanGestureRecognizer(target: self, action: #selector(threefingersHandler(_:)))
        threefingers.numberOfTouchesRequired = 3
        threefingers.allowedTouchTypes = .direct
        view.addGestureRecognizer(threefingers)

        fourfingers = NSPanGestureRecognizer(target: self, action: #selector(fourfingersHandler(_:)))
        fourfingers.numberOfTouchesRequired = 4
        fourfingers.allowedTouchTypes = .direct
        view.addGestureRecognizer(fourfingers)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Angle Calculation
    func calculateDirection(deltaX: CGFloat, deltaY: CGFloat) -> SwipeDirection {
        let absX = abs(deltaX)
        let absY = abs(deltaY)

        // Ignore tiny movements (noise)
        guard absX > 3 || absY > 3 else { return .unknown }

        let angle = atan2(absY, absX) * 180.0 / .pi

        if angle < horizontalAngleMax {
            return deltaX > 0 ? .right : .left
        } else if angle > verticalAngleMin {
            return deltaY > 0 ? .up : .down
        } else {
            // Dead zone between 30°~60°
            return .unknown
        }
    }

    // MARK: - Double Swipe Detection
    func handleDoubleSwipe(_ record: SwipeRecord) {
        if let first = firstSwipe {
            let timeDiff = record.timestamp - first.timestamp

            // Timeout — reset to new first swipe
            if timeDiff > doubleSwipeTimeThreshold {
                firstSwipe = record
                return
            }

            // Same direction + same finger count → trigger!
            if first.direction == record.direction && first.fingers == record.fingers {
                print("✅ Double swipe detected: \(record.direction.description) x\(record.fingers)")
                firstSwipe = nil
                triggerVerticalAction(direction: record.direction, fingers: record.fingers)
            } else {
                // Different direction or fingers — update first
                firstSwipe = record
            }
        } else {
            // First swipe recorded
            firstSwipe = record
        }
    }

    // MARK: - Vertical Action Trigger
    func triggerVerticalAction(direction: SwipeDirection, fingers: Int) {
        for item in swipeItems {
            switch direction {
            case .up:
                // Use large positive offset to pass minOffset check
                item.processEvent(offset: 1000, fingers: fingers)
            case .down:
                // Use large negative offset to pass minOffset check
                item.processEvent(offset: -1000, fingers: fingers)
            default:
                break
            }
        }
    }

    // MARK: - Gesture Handler
    func gestureHandler(position: CGFloat, yPosition: CGFloat, fingers: Int, state: NSGestureRecognizer.State) {
        switch state {
        case .began:
            prevPositions[fingers] = position
            prevYPositions[fingers] = yPosition
            legacyPrevPositions[fingers] = position
        case .changed:
            if self.legacyGesturesEnabled {
                if fingers == 2 {
                    let prevPos = legacyPrevPositions[fingers]!
                    if ((position - prevPos) > 10) || ((prevPos - position) > 10) {
                        if position > prevPos {
                            HIDPostAuxKey(NX_KEYTYPE_SOUND_UP)
                        } else if position < prevPos {
                            HIDPostAuxKey(NX_KEYTYPE_SOUND_DOWN)
                        }
                        legacyPrevPositions[fingers] = position
                    }
                }
                if fingers == 3 {
                    let prevPos = legacyPrevPositions[fingers]!
                    if ((position - prevPos) > 15) || ((prevPos - position) > 15) {
                        if position > prevPos {
                            HIDPostAuxKey(NX_KEYTYPE_BRIGHTNESS_UP)
                        } else if position < prevPos {
                            HIDPostAuxKey(NX_KEYTYPE_BRIGHTNESS_DOWN)
                        }
                        legacyPrevPositions[fingers] = position
                    }
                }
            }
        case .ended:
            let deltaX = position - (prevPositions[fingers] ?? 0)
            let deltaY = yPosition - (prevYPositions[fingers] ?? 0)

            let direction = calculateDirection(deltaX: deltaX, deltaY: deltaY)
            print("Gesture ended: deltaX=\(deltaX), deltaY=\(deltaY), direction=\(direction.description), fingers=\(fingers)")

            if direction.isVertical {
                // Vertical swipe → use double-swipe detection
                let record = SwipeRecord(
                    direction: direction,
                    fingers: fingers,
                    timestamp: Date().timeIntervalSince1970
                )
                handleDoubleSwipe(record)
            } else if direction.isHorizontal {
                // Horizontal swipe → original single-swipe logic
                for item in swipeItems {
                    item.processEvent(offset: deltaX, fingers: fingers)
                }
            }
            // .unknown → do nothing
        default:
            break
        }
    }

    // MARK: - Recognizer Handlers
    @objc func twofingersHandler(_ sender: NSGestureRecognizer?) {
        let loc = sender?.location(in: sender?.view)
        self.gestureHandler(position: loc?.x ?? 0, yPosition: loc?.y ?? 0, fingers: 2, state: sender!.state)
    }

    @objc func threefingersHandler(_ sender: NSGestureRecognizer?) {
        let loc = sender?.location(in: sender?.view)
        self.gestureHandler(position: loc?.x ?? 0, yPosition: loc?.y ?? 0, fingers: 3, state: sender!.state)
    }

    @objc func fourfingersHandler(_ sender: NSGestureRecognizer?) {
        let loc = sender?.location(in: sender?.view)
        self.gestureHandler(position: loc?.x ?? 0, yPosition: loc?.y ?? 0, fingers: 4, state: sender!.state)
    }
}
