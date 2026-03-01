import Foundation
import WebKit

/// Custom URL scheme handler that serves local bundle files over a custom `game://` scheme.
/// This allows WKWebView's JavaScript `fetch()` to load local JSON files normally,
/// since `fetch()` doesn't work with `file://` URLs in WKWebView.
class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "game"

    /// The base directory in the app bundle where game files live.
    private let gamesDirectory: URL?

    init(gamesDirectory: URL?) {
        self.gamesDirectory = gamesDirectory
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let gamesDir = gamesDirectory else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalFileSchemeHandler", code: 404))
            return
        }

        // Extract the path from game://host/path — we only care about the path component
        let path = requestURL.path
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        let fileURL = gamesDir.appendingPathComponent(cleanPath)

        // Security: ensure the resolved path is within the games directory
        guard fileURL.standardizedFileURL.path.hasPrefix(gamesDir.standardizedFileURL.path) else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalFileSchemeHandler", code: 403))
            return
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalFileSchemeHandler", code: 404))
            return
        }

        let mimeType = Self.mimeType(for: fileURL.pathExtension)
        let response = HTTPURLResponse(
            url: requestURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*"
            ]
        )!

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Nothing to cancel
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html"
        case "json": return "application/json"
        case "js":   return "application/javascript"
        case "css":  return "text/css"
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg":  return "image/svg+xml"
        case "gif":  return "image/gif"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf":  return "font/ttf"
        default:     return "application/octet-stream"
        }
    }
}
