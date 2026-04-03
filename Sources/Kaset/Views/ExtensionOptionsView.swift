import SwiftUI
import WebKit

/// A view that displays the options page of a WebKit extension.
@available(macOS 26.0, *)
struct ExtensionOptionsView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WebKitManager.shared.processPool
        #if os(macOS)
        config.webExtensionController = WebKitManager.shared.webExtensionController
        #endif
        
        // Setup bridge
        let controller = WKUserContentController()
        
        // Inject script to pipe console to native
        let consoleProxyScript = WKUserScript(
            source: """
            (function() {
                var oldLog = console.log;
                var oldError = console.error;
                var oldWarn = console.warn;
                console.log = function() {
                    window.webkit.messageHandlers.optionsDebug.postMessage("LOG: " + Array.from(arguments).join(" "));
                    oldLog.apply(console, arguments);
                };
                console.error = function() {
                    window.webkit.messageHandlers.optionsDebug.postMessage("ERROR: " + Array.from(arguments).join(" "));
                    oldError.apply(console, arguments);
                };
                console.warn = function() {
                    window.webkit.messageHandlers.optionsDebug.postMessage("WARN: " + Array.from(arguments).join(" "));
                    oldWarn.apply(console, arguments);
                };
                window.onerror = function(msg, url, line, col, error) {
                    window.webkit.messageHandlers.optionsDebug.postMessage("UNCAUGHT ERROR: " + msg + " at " + url + ":" + line + ":" + col);
                    return false;
                };
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(consoleProxyScript)
        config.userContentController.add(context.coordinator, name: "optionsDebug")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url && !webView.isLoading {
            // Tiny delay to ensure WebKit's internal extension registry has catch up with the ID
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                DiagnosticsLogger.extensions.info("ExtensionOptionsView loading URL: \(url.absoluteString)")
                webView.load(URLRequest(url: url))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "optionsDebug" {
                DiagnosticsLogger.extensions.info("Options Console: \(String(describing: message.body))")
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DiagnosticsLogger.extensions.info("Options page: Provisional navigation started.")
        }
        func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
            DiagnosticsLogger.extensions.info("Options page: Navigation committed.")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            DiagnosticsLogger.extensions.error("Options page navigation failed (Code \(nsError.code)): \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            DiagnosticsLogger.extensions.error("Options page load failed (Code \(nsError.code)): \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DiagnosticsLogger.extensions.info("Options page loaded successfully.")
        }
    }
}
