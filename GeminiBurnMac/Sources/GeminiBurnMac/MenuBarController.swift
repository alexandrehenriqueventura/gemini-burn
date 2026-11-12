import Cocoa
import Combine

final class MenuBarController: NSObject, NSMenuDelegate {
    private let floatingWindow: FloatingWindow
    private let pythonBackend: PythonBackend
    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu!
    private var cancellables = Set<AnyCancellable>()

    private enum MenuTag: Int {
        case status = 100
        case port = 101
        case toggleWindow = 200
        case pinWindow = 201
    }

    init(floatingWindow: FloatingWindow, pythonBackend: PythonBackend) {
        self.floatingWindow = floatingWindow
        self.pythonBackend = pythonBackend
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        if let image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Gemini Burn") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "🔥"
        }

        button.toolTip = "Gemini Burn • Clique esquerdo: Widget | Clique direito: Menu"
        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        setupMenu()
        observeState()
    }

    private func setupMenu() {
        let menuObj = NSMenu()
        menuObj.delegate = self

        let toggleItem = NSMenuItem(
            title: "Mostrar Widget",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.tag = MenuTag.toggleWindow.rawValue
        menuObj.addItem(toggleItem)

        let pinItem = NSMenuItem(
            title: "Fixar Janela",
            action: #selector(togglePin),
            keyEquivalent: ""
        )
        pinItem.target = self
        pinItem.tag = MenuTag.pinWindow.rawValue
        menuObj.addItem(pinItem)

        menuObj.addItem(NSMenuItem.separator())

        let statusMenuItem = NSMenuItem(
            title: "Backend: Iniciando...",
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = MenuTag.status.rawValue
        menuObj.addItem(statusMenuItem)

        let portItem = NSMenuItem(
            title: "Porta: \(pythonBackend.port)",
            action: nil,
            keyEquivalent: ""
        )
        portItem.isEnabled = false
        portItem.tag = MenuTag.port.rawValue
        menuObj.addItem(portItem)

        menuObj.addItem(NSMenuItem.separator())

        let restartItem = NSMenuItem(
            title: "Reiniciar Backend",
            action: #selector(restartBackend),
            keyEquivalent: ""
        )
        restartItem.target = self
        menuObj.addItem(restartItem)

        let browserItem = NSMenuItem(
            title: "Abrir no Navegador",
            action: #selector(openInBrowser),
            keyEquivalent: ""
        )
        browserItem.target = self
        menuObj.addItem(browserItem)

        menuObj.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Sair",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menuObj.addItem(quitItem)

        self.contextMenu = menuObj
    }

    private func observeState() {
        Publishers.CombineLatest3(pythonBackend.$isRunning, pythonBackend.$isReady, pythonBackend.$port)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running, ready, port in
                self?.updateMenuStatus(running: running, ready: ready, port: port)
            }
            .store(in: &cancellables)

        pythonBackend.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.showError(error)
                }
            }
            .store(in: &cancellables)

        floatingWindow.onVisibilityChanged = { [weak self] visible in
            self?.updateVisibilityItem(visible: visible)
        }

        floatingWindow.onPinnedChanged = { [weak self] pinned in
            self?.updatePinItem(pinned: pinned)
        }
    }

    private func updateMenuStatus(running: Bool, ready: Bool, port: Int) {
        if let statusMenuItem = contextMenu.item(withTag: MenuTag.status.rawValue) {
            if ready {
                statusMenuItem.title = "Backend: ● Conectado"
            } else if running {
                statusMenuItem.title = "Backend: ◐ Iniciando..."
            } else {
                statusMenuItem.title = "Backend: ○ Desconectado"
            }
        }
        if let portMenuItem = contextMenu.item(withTag: MenuTag.port.rawValue) {
            portMenuItem.title = "Porta: \(port)"
        }
        updateVisibilityItem(visible: floatingWindow.isVisible)
        updatePinItem(pinned: floatingWindow.isPinned)
    }

    private func updateVisibilityItem(visible: Bool) {
        if let toggleMenuItem = contextMenu.item(withTag: MenuTag.toggleWindow.rawValue) {
            toggleMenuItem.title = visible ? "Ocultar Widget" : "Mostrar Widget"
        }
    }

    private func updatePinItem(pinned: Bool) {
        if let pinMenuItem = contextMenu.item(withTag: MenuTag.pinWindow.rawValue) {
            pinMenuItem.state = pinned ? .on : .off
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            toggleWindow()
            return
        }

        let isRightOrCtrlClick = event.type == .rightMouseUp ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightOrCtrlClick {
            showContextMenu(from: sender)
        } else {
            toggleWindow()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        updateMenuStatus(running: pythonBackend.isRunning, ready: pythonBackend.isReady, port: pythonBackend.port)
        statusItem?.menu = contextMenu
        button.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }

    @objc func toggleWindow() {
        floatingWindow.toggle()
        updateVisibilityItem(visible: floatingWindow.isVisible)
    }

    @objc func togglePin() {
        floatingWindow.togglePinned()
        updatePinItem(pinned: floatingWindow.isPinned)
    }

    @objc func restartBackend() {
        pythonBackend.restart()
    }

    @objc func openInBrowser() {
        guard let url = URL(string: pythonBackend.baseURL) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Gemini Burn"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
