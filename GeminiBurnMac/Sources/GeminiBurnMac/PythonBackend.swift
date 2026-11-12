import Foundation
import Combine
import Darwin
import WidgetKit

final class PythonBackend: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isReady = false
    @Published private(set) var port: Int = 5678
    @Published var lastError: String?

    private var process: Process?
    private var outputPipe: Pipe?
    private var readinessTimer: DispatchSourceTimer?
    private var widgetRefreshTimer: DispatchSourceTimer?
    private let pythonExecutablePath: String?
    private let pythonScriptPath: String?

    init() {
        self.pythonExecutablePath = Self.resolvePythonExecutable()
        self.pythonScriptPath = Self.resolvePythonScript()
    }

    var baseURL: String {
        "http://127.0.0.1:\(port)"
    }

    func start() {
        guard let pythonExec = pythonExecutablePath else {
            lastError = "Python 3 não encontrado. Instale o Python 3 ou as Xcode Command Line Tools."
            return
        }

        guard let scriptPath = pythonScriptPath else {
            lastError = "Backend Python não encontrado (gemini-burn-widget/main.py)."
            return
        }

        guard !isRunning else { return }

        let chosenPort = Self.findAvailablePort(preferred: 5678)
        self.port = chosenPort
        self.isReady = false
        self.lastError = nil

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonExec)
        proc.arguments = [scriptPath, "--web", "--port", "\(chosenPort)"]
        proc.currentDirectoryURL = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        self.outputPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                print("[Python Backend] \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        proc.terminationHandler = { [weak self] terminatedProc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stopReadinessPolling()
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.outputPipe = nil
                self.isRunning = false
                self.isReady = false
                self.process = nil
                if terminatedProc.terminationReason == .uncaughtSignal || terminatedProc.terminationStatus != 0 {
                    // Only surface error if unexpected termination while running
                    if self.lastError == nil && terminatedProc.terminationStatus != 15 && terminatedProc.terminationStatus != 0 {
                        self.lastError = "Backend Python encerrou inesperadamente (código \(terminatedProc.terminationStatus))."
                    }
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.isRunning = true
            startReadinessPolling(port: chosenPort)
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            self.outputPipe = nil
            self.isRunning = false
            self.isReady = false
            self.lastError = "Falha ao iniciar o backend Python: \(error.localizedDescription)"
        }
    }

    func stop() {
        stopReadinessPolling()
        stopWidgetRefreshTimer()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        process = nil
        isRunning = false
        isReady = false
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start()
        }
    }

    // MARK: - Readiness Polling

    private func startReadinessPolling(port: Int) {
        stopReadinessPolling()
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/stats") else { return }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 0.1, repeating: 0.25)

        var attempts = 0
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            attempts += 1

            var request = URLRequest(url: url)
            request.timeoutInterval = 0.5

            let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
                guard let self = self else { return }
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    DispatchQueue.main.async {
                        self.stopReadinessPolling()
                        self.isReady = true
                        WidgetCenter.shared.reloadTimelines(ofKind: "com.geminiburn.mac.widget")
                        self.startWidgetRefreshTimer()
                    }
                } else if attempts >= 40 {
                    DispatchQueue.main.async {
                        self.stopReadinessPolling()
                        if self.isRunning && !self.isReady {
                            self.lastError = "Backend Python não respondeu na porta \(port)."
                        }
                    }
                }
            }
            task.resume()
        }
        self.readinessTimer = timer
        timer.resume()
    }

    private func stopReadinessPolling() {
        readinessTimer?.cancel()
        readinessTimer = nil
    }

    private func startWidgetRefreshTimer() {
        stopWidgetRefreshTimer()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler {
            WidgetCenter.shared.reloadTimelines(ofKind: "com.geminiburn.mac.widget")
        }
        self.widgetRefreshTimer = timer
        timer.resume()
    }

    private func stopWidgetRefreshTimer() {
        widgetRefreshTimer?.cancel()
        widgetRefreshTimer = nil
    }

    // MARK: - Path & Port Resolution

    private static func resolvePythonExecutable() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func resolvePythonScript() -> String? {
        let bundle = Bundle.main
        var candidates: [String] = []

        if let bundled = bundle.path(forResource: "main", ofType: "py", inDirectory: "gemini-burn-widget") {
            candidates.append(bundled)
        }
        if let resourcePath = bundle.resourcePath {
            candidates.append("\(resourcePath)/gemini-burn-widget/main.py")
        }

        // Dev fallbacks relative to CWD / bundle location
        let cwd = FileManager.default.currentDirectoryPath
        candidates.append("\(cwd)/gemini-burn-widget/main.py")
        candidates.append("\(cwd)/../gemini-burn-widget/main.py")

        let bundleParent = bundle.bundleURL.deletingLastPathComponent().path
        candidates.append("\(bundleParent)/../../gemini-burn-widget/main.py")
        candidates.append("\(NSHomeDirectory())/gemini-burn-widget/main.py")

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private static func findAvailablePort(preferred: Int) -> Int {
        for candidate in preferred..<(preferred + 20) {
            if isPortFree(candidate) {
                return candidate
            }
        }
        return preferred
    }

    private static func isPortFree(_ port: Int) -> Bool {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}
