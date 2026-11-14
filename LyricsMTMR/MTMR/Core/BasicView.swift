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

        // Split left / flexible center / right so leftover bar width is absorbed
        // by the center (or by gaps between side items) instead of a trailing void.
        var leading: [NSView] = []
        var center: NSView?
        var trailing: [NSView] = []
        var seenCenter = false
        for item in items {
            guard let itemView = item.view else { continue }
            if item is ScrollViewItem {
                center = itemView
                seenCenter = true
            } else if seenCenter {
                trailing.append(itemView)
            } else {
                leading.append(itemView)
            }
        }

        let centerHasContent = (items.first(where: { $0 is ScrollViewItem }) as? ScrollViewItem)?.hasContent ?? false
        let arranged = Self.arrangedFillViews(leading: leading, center: center, trailing: trailing, centerHasContent: centerHasContent)
        let stackView = NSStackView(views: arranged)
        stackView.spacing = 8
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fill

        let root = NSView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: root.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            root.widthAnchor.constraint(equalToConstant: Self.barContentWidth),
            root.heightAnchor.constraint(equalToConstant: 30),
        ])
        view = root

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

    /// Hardware content width inside the 24cm / 1085pt bar.
    ///
    /// The system-tray item (our control-strip button) always owns the trailing
    /// band — even with “隐藏 Control Strip” (`placement: 1`). Requesting the
    /// full 1085pt slides the right cluster under that tray (exit clipped,
    /// settings half-hidden). Reserve roughly one action button (~75pt) so the
    /// rightmost widgets sit fully on-screen.
    static var barContentWidth: CGFloat {
        let logical = TouchBarSurfaceView.logicalWidth
        if AppSettings.showControlStripState {
            // Expanded Control Strip (volume/brightness/…) is much wider.
            return max(480, logical - 280)
        }
        return max(480, logical - trailingTrayReserve)
    }

    /// Trailing reserve for the system-tray / collapsed control strip.
    /// Measured on hardware: forcing 1085 clipped about one pomodoro-sized
    /// action button; +15pt more so the right cluster clears the tray fully.
    static let trailingTrayReserve: CGFloat = 90

    /// Pure fill strategy (unit-testable): one flexible region, packed sides.
    /// When the center is empty and there is no right cluster, spread the left
    /// items themselves so sparse themes still occupy the full bar.
    static func arrangedFillViews(leading: [NSView], center: NSView?, trailing: [NSView], centerHasContent: Bool) -> [NSView] {
        if centerHasContent, let center {
            return leading + [center] + trailing
        }
        if !trailing.isEmpty {
            return leading + [makeFlexibleSpacer()] + trailing
        }
        guard leading.count > 1 else { return leading }
        // Spread left cluster across the bar (no trailing pad).
        var arranged: [NSView] = []
        for (index, item) in leading.enumerated() {
            if index > 0 { arranged.append(makeFlexibleSpacer()) }
            arranged.append(item)
        }
        return arranged
    }

    private static func makeFlexibleSpacer() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        return spacer
    }

    required init?(coder _: NSCoder) { return nil }

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
