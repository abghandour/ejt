import UIKit
import WebKit

/// Handles JavaScript-to-native communication from game WebViews.
/// Supports `nativeShare` message handler and injects `window.patreonUser`.
class JSBridge: NSObject, WKScriptMessageHandler {

    /// Message handler name for the native share feature.
    static let nativeShareHandler = "nativeShare"

    /// Registers the `nativeShare` message handler on the given content controller.
    static func register(on controller: WKUserContentController, bridge: JSBridge) {
        controller.add(bridge, name: nativeShareHandler)
    }

    /// Creates a `WKUserScript` that injects `window.patreonUser` at document start.
    static func userScript(patreonDisplayName: String?) -> WKUserScript {
        let escaped = escapeForJavaScript(patreonDisplayName ?? "Player")
        let source = "window.patreonUser = \"\(escaped)\";"
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    /// Escapes a string for safe embedding inside a JavaScript double-quoted string literal.
    static func escapeForJavaScript(_ value: String) -> String {
        var result = ""
        for char in value {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "'":  result += "\\'"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\0": result += "\\0"
            default:
                if char.asciiValue == nil || char.asciiValue! < 0x20 {
                    for scalar in char.unicodeScalars {
                        result += String(format: "\\u{%X}", scalar.value)
                    }
                } else {
                    result.append(char)
                }
            }
        }
        return result
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == JSBridge.nativeShareHandler else { return }

        let text: String
        if let body = message.body as? String {
            text = body
        } else {
            text = String(describing: message.body)
        }

        presentShareSheet(with: text)
    }

    // MARK: - Private

    private func presentShareSheet(with text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                        y: presenter.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }
}
