import Cocoa
import WebKit
import Combine

final class FloatingWindow: NSWindow {
    private var webView: WKWebView!
    private(set) var isPinned = false
    private let pythonBackend: PythonBackend
    private var cancellables = Set<AnyCancellable>()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastMouseDownEvent: NSEvent?
    private var hasLoadedInitialPage = false

    private let windowWidth: CGFloat = 380
    private let windowHeight: CGFloat = 580

    var onVisibilityChanged: ((Bool) -> Void)?
    var onPinnedChanged: ((Bool) -> Void)?

    init(pythonBackend: PythonBackend) {
        self.pythonBackend = pythonBackend

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowRect = NSRect(
            x: screenFrame.maxX - windowWidth - 20,
            y: screenFrame.maxY - windowHeight - 20,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupWebView()
        setupObservers()
    }

    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isMovableByWindowBackground = true

        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 20
        contentView?.layer?.masksToBounds = true
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let contentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(delegate: self)
        contentController.add(proxy, name: "geminiBurn")

        let bridgeScript = WKUserScript(
            source: Self.nativeBridgeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)
        config.userContentController = contentController

        let bounds = contentView?.bounds ?? NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.layer?.backgroundColor = CGColor.clear
        webView.layer?.cornerRadius = 20
        webView.layer?.masksToBounds = true
        webView.navigationDelegate = self
        webView.uiDelegate = self

        contentView?.addSubview(webView)
    }

    private func setupObservers() {
        pythonBackend.$isReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ready in
                guard let self = self, ready else { return }
                self.loadContent()
            }
            .store(in: &cancellables)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            if event.window === self {
                self?.lastMouseDownEvent = event
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible, !self.isPinned else { return }
            if !self.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
        }
    }

    func loadContent() {
        guard let url = URL(string: "\(pythonBackend.baseURL)/") else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        hasLoadedInitialPage = true
        webView.load(request)
    }

    func show() {
        if !hasLoadedInitialPage && pythonBackend.isReady {
            loadContent()
        }
        guard !isVisible else { return }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onVisibilityChanged?(true)
    }

    func hide() {
        guard isVisible else { return }
        orderOut(nil)
        onVisibilityChanged?(false)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func setPinned(_ pinned: Bool, syncWebUI: Bool = true) {
        guard isPinned != pinned else { return }
        isPinned = pinned
        onPinnedChanged?(pinned)

        if syncWebUI {
            let js = "window.__geminiBurnSetPinned && window.__geminiBurnSetPinned(\(pinned ? "true" : "false"));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func togglePinned() {
        setPinned(!isPinned, syncWebUI: true)
    }

    deinit {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "geminiBurn")
    }

    private static let nativeBridgeJS = """
    (function() {
        if (window.__geminiBurnBridgeInstalled) return;
        window.__geminiBurnBridgeInstalled = true;

        const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.geminiBurn;
        if (!handler) return;

        // Intercept fetch calls for /api/hide and /api/config (pinned)
        const originalFetch = window.fetch.bind(window);
        window.fetch = function(input, init) {
            try {
                const url = typeof input === 'string' ? input : (input && input.url) || '';
                if (url.endsWith('/api/hide')) {
                    handler.postMessage({ action: 'hide' });
                } else if (url.endsWith('/api/config') && init && typeof init.body === 'string') {
                    const parsed = JSON.parse(init.body);
                    if (typeof parsed.pinned === 'boolean') {
                        handler.postMessage({ action: 'pin', pinned: parsed.pinned });
                    }
                }
            } catch (_) {}
            return originalFetch(input, init);
        };

        // Allow native window drag from .widget-header (excluding interactive buttons)
        document.addEventListener('mousedown', function(e) {
            if (e.button !== 0) return;
            const header = e.target && e.target.closest ? e.target.closest('.widget-header') : null;
            if (!header) return;
            if (e.target.closest('button, a, input, select, textarea')) return;
            handler.postMessage({ action: 'startDrag' });
        }, false);

        // Expose helper to sync pin button visual state when toggled from Menu Bar
        window.__geminiBurnSetPinned = function(pinned) {
            const btnPin = document.getElementById('btnPin');
            if (!btnPin) return;
            btnPin.style.background = pinned ? 'rgba(249, 115, 22, 0.3)' : '';
            btnPin.style.borderColor = pinned ? '#f97316' : '';
            btnPin.title = pinned ? 'Janela Fixada (clique para desafixar)' : 'Fixar na tela';
        };
    })();
    """
}

extension FloatingWindow: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "geminiBurn",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "hide":
            hide()
        case "pin":
            if let pinned = body["pinned"] as? Bool {
                setPinned(pinned, syncWebUI: false)
            }
        case "startDrag":
            if let event = lastMouseDownEvent ?? NSApp.currentEvent, event.type == .leftMouseDown {
                performDrag(with: event)
            }
        default:
            break
        }
    }
}

extension FloatingWindow: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView load failed: \(error.localizedDescription)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.pythonBackend.isReady else { return }
            self.loadContent()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           url.scheme?.hasPrefix("http") == true {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

extension FloatingWindow: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
