import UIKit

// =============================================================================
// TouchVisualizer — overlay de puntos de toque para capturas de tutorial
// =============================================================================
//
// ACTIVACIÓN: exclusivamente por `-UIProbeTouchViz` (pasado por XCUITest en el
// GearScenarioTests). En producción el flag está ausente → la window no se crea.
//
// DISEÑO (cero interferencia con gestos):
//   - UIWindow secundaria (windowLevel .alert + 100) con isUserInteractionEnabled=false.
//   - La subclase TouchVisualizerWindow sobreescribe hitTest(_:with:) → siempre nil
//     (pass-through total: todos los toques caen a la window principal).
//   - Los toques se interceptan en la window PRINCIPAL mediante un
//     UIGestureRecognizer no-bloqueante (cancelsTouchesInView=false,
//     delaysTouchesBegan=false, delaysTouchesEnded=false) — no bloquea ni retrasa
//     ningún gesto real del MetalView ni del resto de la UI.
//   - Cada toque activo dibuja un círculo ember (~44pt, alpha 0.5) que desaparece
//     con fade-out en ~200 ms al levantar el dedo.
//
// HILO: toda la UI de UIKit corre en main thread; los métodos aquí se llaman
// siempre desde main (UIGestureRecognizer callbacks y UIView drawing).

// MARK: - Ventana pass-through

/// UIWindow secundaria que dibuja los overlays pero NO captura ningún toque.
private final class TouchVisualizerWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Pass-through total: devolver nil dirige el toque a la window debajo.
        return nil
    }
}

// MARK: - Vista de dibujo

private final class TouchDotView: UIView {
    private let color = UIColor(red: 1.0, green: 0.48, blue: 0.27, alpha: 0.5)  // ember

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: bounds)
    }
}

// MARK: - Reconocedor no-bloqueante

/// GestureRecognizer que observa los toques SIN robarlos, notificando a TouchVisualizer.
private final class TouchObserverGesture: UIGestureRecognizer {
    weak var visualizer: TouchVisualizer?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        visualizer?.showTouches(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        visualizer?.moveTouches(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        visualizer?.endTouches(touches)
        // Reset para el próximo ciclo de toques. Never .recognized — nunca bloquea.
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        visualizer?.endTouches(touches)
        state = .failed
    }
}

// MARK: - Coordinador principal

/// Instala y gestiona el overlay de puntos de toque.
/// Usar `TouchVisualizer.install(in:)` desde el punto de entrada de la app.
@MainActor
final class TouchVisualizer {

    private var overlayWindow: TouchVisualizerWindow?
    private var overlayRoot: UIView?
    /// Mapa touch → dot view (clave = ObjectIdentifier para evitar hashear UITouch).
    private var dots: [ObjectIdentifier: TouchDotView] = [:]
    private let dotSize: CGFloat = 44

    // MARK: - Instalación

    /// Instala el visualizador en la escena dada.
    /// No-op si el flag `-UIProbeTouchViz` no está presente.
    static func installIfNeeded(in scene: UIWindowScene) {
        guard UIProbeMode.touchVizActive else { return }
        let viz = TouchVisualizer()
        viz.install(in: scene)
        // Retener en la escena para que no sea desallocado.
        objc_setAssociatedObject(scene, &TouchVisualizer.associatedKey, viz,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static var associatedKey = "TouchVisualizerKey"

    private func install(in scene: UIWindowScene) {
        // Crear la ventana overlay pass-through.
        let win = TouchVisualizerWindow(windowScene: scene)
        win.windowLevel = .alert + 100
        win.backgroundColor = .clear
        win.isUserInteractionEnabled = false

        let root = UIView(frame: scene.coordinateSpace.bounds)
        root.backgroundColor = .clear
        root.isUserInteractionEnabled = false
        win.rootViewController = {
            let vc = UIViewController()
            vc.view = root
            return vc
        }()
        win.makeKeyAndVisible()
        // La ventana principal recupera key-window status.
        scene.windows.first(where: { $0 !== win })?.makeKeyAndVisible()

        overlayWindow = win
        overlayRoot = root

        // Instalar el reconocedor no-bloqueante en la ventana principal.
        if let mainWindow = scene.windows.first(where: { !($0 is TouchVisualizerWindow) }) {
            let gesture = TouchObserverGesture(target: nil, action: nil)
            gesture.visualizer = self
            mainWindow.addGestureRecognizer(gesture)
        }
    }

    // MARK: - Gestión de dots

    func showTouches(_ touches: Set<UITouch>) {
        guard let root = overlayRoot else { return }
        for touch in touches {
            let pt = touch.location(in: root)
            let dot = TouchDotView(frame: CGRect(
                x: pt.x - dotSize / 2, y: pt.y - dotSize / 2,
                width: dotSize, height: dotSize
            ))
            dot.layer.cornerRadius = dotSize / 2
            dot.clipsToBounds = true
            dot.isOpaque = false
            dot.backgroundColor = .clear
            root.addSubview(dot)
            dots[ObjectIdentifier(touch)] = dot
        }
    }

    func moveTouches(_ touches: Set<UITouch>) {
        guard let root = overlayRoot else { return }
        for touch in touches {
            guard let dot = dots[ObjectIdentifier(touch)] else { continue }
            let pt = touch.location(in: root)
            dot.center = pt
        }
    }

    func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard let dot = dots.removeValue(forKey: key) else { continue }
            UIView.animate(withDuration: 0.2, animations: {
                dot.alpha = 0
            }, completion: { _ in
                dot.removeFromSuperview()
            })
        }
    }
}
