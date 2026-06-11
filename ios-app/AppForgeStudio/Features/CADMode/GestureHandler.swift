import SwiftUI
import UIKit

struct GestureHandler: UIViewRepresentable {
    var onOrbit: ((CGPoint, CGPoint) -> Void)?
    var onPan: ((CGPoint, CGPoint) -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onLongPress: ((CGPoint) -> Void)?
    var onPencilForce: ((CGFloat, CGPoint) -> Void)?
    var onTwoFingerTap: ((CGPoint) -> Void)?
    var onSwipeUp: ((CGPoint) -> Void)?
    var onSwipeDown: ((CGPoint) -> Void)?
    var onPencilDoubleTap: ((CGPoint, CGFloat) -> Void)?
    var onRotation: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> GestureHandlerView {
        let view = GestureHandlerView()
        view.onOrbit = onOrbit
        view.onPan = onPan
        view.onZoom = onZoom
        view.onTap = onTap
        view.onLongPress = onLongPress
        view.onPencilForce = onPencilForce
        view.onTwoFingerTap = onTwoFingerTap
        view.onSwipeUp = onSwipeUp
        view.onSwipeDown = onSwipeDown
        view.onPencilDoubleTap = onPencilDoubleTap
        view.onRotation = onRotation
        return view
    }

    func updateUIView(_ uiView: GestureHandlerView, context: Context) {
        uiView.onOrbit = onOrbit
        uiView.onPan = onPan
        uiView.onZoom = onZoom
        uiView.onTap = onTap
        uiView.onLongPress = onLongPress
        uiView.onPencilForce = onPencilForce
        uiView.onTwoFingerTap = onTwoFingerTap
        uiView.onSwipeUp = onSwipeUp
        uiView.onSwipeDown = onSwipeDown
        uiView.onPencilDoubleTap = onPencilDoubleTap
        uiView.onRotation = onRotation
    }
}

class GestureHandlerView: UIView {
    var onOrbit: ((CGPoint, CGPoint) -> Void)?
    var onPan: ((CGPoint, CGPoint) -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onLongPress: ((CGPoint) -> Void)?
    var onPencilForce: ((CGFloat, CGPoint) -> Void)?
    var onTwoFingerTap: ((CGPoint) -> Void)?
    var onSwipeUp: ((CGPoint) -> Void)?
    var onSwipeDown: ((CGPoint) -> Void)?
    var onPencilDoubleTap: ((CGPoint, CGFloat) -> Void)?
    var onRotation: ((CGFloat) -> Void)?
    
    // Debounce: minimum interval (seconds) between firing the same callback
    private var lastGestureTime: [String: TimeInterval] = [:]
    private let debounceInterval: TimeInterval = 0.1
    
    private func shouldFire(_ key: String) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastGestureTime[key], now - last < debounceInterval {
            return false
        }
        lastGestureTime[key] = now
        return true
    }
    
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    private var longPressGesture: UILongPressGestureRecognizer!
    private var twoFingerTapGesture: UITapGestureRecognizer!
    private var swipeUpGesture: UISwipeGestureRecognizer!
    private var swipeDownGesture: UISwipeGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    private var pencilInteraction: UIPencilInteraction?

    private var lastPencilForce: CGFloat = 0
    private let feedbackGen = UIImpactFeedbackGenerator(style: .light)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        setupGestures()
        feedbackGen.prepare()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        setupGestures()
        feedbackGen.prepare()
    }

    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)

        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
        addGestureRecognizer(rotationGesture)

        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)

        twoFingerTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTapGesture.numberOfTouchesRequired = 2
        twoFingerTapGesture.delegate = self
        addGestureRecognizer(twoFingerTapGesture)

        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        addGestureRecognizer(longPressGesture)

        swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp(_:)))
        swipeUpGesture.direction = .up
        swipeUpGesture.delegate = self
        addGestureRecognizer(swipeUpGesture)

        swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown(_:)))
        swipeDownGesture.direction = .down
        swipeDownGesture.delegate = self
        addGestureRecognizer(swipeDownGesture)

        if #available(iOS 17.0, *) {
            pencilInteraction = UIPencilInteraction()
            pencilInteraction?.delegate = self
            addInteraction(pencilInteraction!)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let translation = gesture.translation(in: self)

        if gesture.state == .began {
            feedbackGen.impactOccurred()
        }

        switch gesture.numberOfTouches {
        case 1:
            onOrbit?(location, translation)
        case 2:
            onPan?(location, translation)
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            feedbackGen.impactOccurred()
        }
        onZoom?(gesture.scale)
        gesture.scale = 1.0
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .began {
            feedbackGen.impactOccurred()
        }
        onRotation?(gesture.rotation)
        gesture.rotation = 0
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        onTap?(location)
    }

    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.numberOfTouches == 2 else { return }
        let location = gesture.location(in: self)
        onTwoFingerTap?(location)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: self)
        feedbackGen.impactOccurred()
        onLongPress?(location)
    }

    @objc private func handleSwipeUp(_ gesture: UISwipeGestureRecognizer) {
        let location = gesture.location(in: self)
        feedbackGen.impactOccurred()
        onSwipeUp?(location)
    }

    @objc private func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        let location = gesture.location(in: self)
        feedbackGen.impactOccurred()
        onSwipeDown?(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first, touch.type == .pencil else { return }
        let force = max(0, min(1, touch.force / touch.maximumPossibleForce))
        let location = touch.location(in: self)
        onPencilForce?(force, location)

        if abs(force - lastPencilForce) > 0.15 {
            feedbackGen.impactOccurred(intensity: CGFloat(force))
        }
        lastPencilForce = force

        if let coalesced = event?.coalescedTouches(for: touch) {
            for ct in coalesced {
                let cforce = max(0, min(1, ct.force / ct.maximumPossibleForce))
                let cloc = ct.location(in: self)
                onPencilForce?(cforce, cloc)
            }
        }
    }
}

extension GestureHandlerView: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        let location = interaction.location(in: self)
        onPencilDoubleTap?(location, lastPencilForce)
    }
}

extension GestureHandlerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
