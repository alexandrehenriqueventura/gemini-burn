import Cocoa
import WidgetKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pythonBackend: PythonBackend?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSignalHandlers()

        let backend = PythonBackend()
        self.pythonBackend = backend
        backend.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pythonBackend?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WidgetCenter.shared.reloadTimelines(ofKind: "com.geminiburn.mac.widget")
        return true
    }

    private func setupSignalHandlers() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.pythonBackend?.stop()
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}
