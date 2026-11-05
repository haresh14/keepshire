import UIKit

/// Blanks system captures of a whole window by moving its layer into the canvas iOS
/// renders secure text fields into. Everything the window draws is covered — the vault,
/// sheets, pickers, and full-screen previews — because they all live in that window.
/// Nothing about the app's own appearance changes: the layer is only reparented.
final class ScreenCaptureBlanker {
    private let secureField = UITextField()
    private weak var blankedWindow: UIWindow?
    private weak var restoredSuperlayer: CALayer?

    var isActive: Bool { blankedWindow != nil }

    func isBlanking(_ window: UIWindow) -> Bool { blankedWindow === window }

    /// Only an on-screen window can be blanked. A window outside any layer tree has nowhere
    /// to put the field back, and reparenting it anyway leaves UIKit's view and layer trees
    /// disagreeing, which crashes when the field is freed.
    @discardableResult
    func apply(to window: UIWindow) -> Bool {
        if blankedWindow === window { return true }
        guard let host = window.layer.superlayer else { return false }
        remove()

        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        secureField.isAccessibilityElement = false
        secureField.backgroundColor = .clear
        // The canvas only exists while the field is in a view hierarchy.
        window.addSubview(secureField)
        secureField.frame = .zero
        secureField.layoutIfNeeded()

        guard let canvas = secureField.layer.sublayers?.last else {
            secureField.removeFromSuperview()
            return false
        }

        secureField.layer.removeFromSuperlayer()
        window.layer.removeFromSuperlayer()
        canvas.addSublayer(window.layer)
        host.addSublayer(secureField.layer)

        restoredSuperlayer = host
        blankedWindow = window
        return true
    }

    func remove() {
        guard let window = blankedWindow else { return }
        window.layer.removeFromSuperlayer()
        restoredSuperlayer?.addSublayer(window.layer)
        secureField.layer.removeFromSuperlayer()
        secureField.removeFromSuperview()
        blankedWindow = nil
        restoredSuperlayer = nil
    }
}

enum SecurityNoticeCopy {
    static let screenshotTitle = "Screenshot is blank"
    static let screenshotMessage =
        "Your vault stayed on screen. The image in Photos is a black frame, not a picture of your files. Apps cannot stop iOS from taking a screenshot."
}
