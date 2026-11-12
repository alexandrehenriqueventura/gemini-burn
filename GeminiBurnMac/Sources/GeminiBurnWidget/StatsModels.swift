import Foundation
import WidgetKit

struct StatsResponse: Codable {
    let status: String
    let updatedAt: String
    let today: TodayStats
    let week: WeekStats
    let pace: PaceStats
    let session: SessionStats
    let sparkline: [SparklineDay]

    enum CodingKeys: String, CodingKey {
        case status
        case updatedAt = "updated_at"
        case today, week, pace, session, sparkline
    }
}

struct TodayStats: Codable {
    let reqs: Int
    let totalTokensFmt: String
    let tokensInFmt: String
    let tokensOutFmt: String
    let limit: Int
    let pct: Double

    enum CodingKeys: String, CodingKey {
        case reqs, limit, pct
        case totalTokensFmt = "total_tokens_fmt"
        case tokensInFmt = "tokens_in_fmt"
        case tokensOutFmt = "tokens_out_fmt"
    }
}

struct WeekStats: Codable {
    let reqs: Int
    let totalTokensFmt: String

    enum CodingKeys: String, CodingKey {
        case reqs
        case totalTokensFmt = "total_tokens_fmt"
    }
}

struct PaceStats: Codable {
    let reqsHour: Int
    let tokensHourFmt: String
    let label: String
    let paceClass: String

    enum CodingKeys: String, CodingKey {
        case label
        case reqsHour = "reqs_hour"
        case tokensHourFmt = "tokens_hour_fmt"
        case paceClass = "class"
    }
}

struct SessionStats: Codable {
    let activeConvShort: String
    let model: String
    let toolsCount: Int
    let lastActive: String

    enum CodingKeys: String, CodingKey {
        case model
        case activeConvShort = "active_conv_short"
        case toolsCount = "tools_count"
        case lastActive = "last_active"
    }
}

struct SparklineDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let label: String
    let reqs: Int
    let tokensFmt: String
    let isToday: Bool

    enum CodingKeys: String, CodingKey {
        case date, label, reqs
        case tokensFmt = "tokens_fmt"
        case isToday = "is_today"
    }
}

struct BurnEntry: TimelineEntry {
    let date: Date
    let stats: StatsResponse
    let isConnected: Bool

    static let placeholder = BurnEntry(
        date: Date(),
        stats: StatsResponse(
            status: "connected",
            updatedAt: "--:--:--",
            today: TodayStats(reqs: 142, totalTokensFmt: "1.24M", tokensInFmt: "1.10M", tokensOutFmt: "140K", limit: 500, pct: 28.4),
            week: WeekStats(reqs: 410, totalTokensFmt: "3.42M"),
            pace: PaceStats(reqsHour: 24, tokensHourFmt: "210K", label: "Ativo ⚡", paceClass: "active"),
            session: SessionStats(activeConvShort: "497ad1b2...", model: "Gemini 3.8 Flash", toolsCount: 1280, lastActive: "agora"),
            sparkline: [
                SparklineDay(date: "d1", label: "Qui", reqs: 80, tokensFmt: "640K", isToday: false),
                SparklineDay(date: "d2", label: "Sex", reqs: 45, tokensFmt: "320K", isToday: false),
                SparklineDay(date: "d3", label: "Sáb", reqs: 110, tokensFmt: "890K", isToday: false),
                SparklineDay(date: "d4", label: "Dom", reqs: 165, tokensFmt: "1.4M", isToday: false),
                SparklineDay(date: "d5", label: "Seg", reqs: 92, tokensFmt: "780K", isToday: false),
                SparklineDay(date: "d6", label: "Ter", reqs: 30, tokensFmt: "210K", isToday: false),
                SparklineDay(date: "d7", label: "Hoje", reqs: 142, tokensFmt: "1.24M", isToday: true),
            ]
        ),
        isConnected: true
    )

    static let disconnected = BurnEntry(
        date: Date(),
        stats: StatsResponse(
            status: "offline",
            updatedAt: "--:--",
            today: TodayStats(reqs: 0, totalTokensFmt: "0", tokensInFmt: "0", tokensOutFmt: "0", limit: 500, pct: 0),
            week: WeekStats(reqs: 0, totalTokensFmt: "0"),
            pace: PaceStats(reqsHour: 0, tokensHourFmt: "0", label: "Offline", paceClass: "idle"),
            session: SessionStats(activeConvShort: "idle", model: "Abra o Gemini Burn", toolsCount: 0, lastActive: "offline"),
            sparkline: []
        ),
        isConnected: false
    )
}

struct StatsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BurnEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BurnEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        fetchStats { entry in
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BurnEntry>) -> Void) {
        fetchStats { entry in
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchStats(completion: @escaping (BurnEntry) -> Void) {
        fetchFromPorts(Array(5678...5683), index: 0, completion: completion)
    }

    private func fetchFromPorts(_ ports: [Int], index: Int, completion: @escaping (BurnEntry) -> Void) {
        guard index < ports.count else {
            completion(.disconnected)
            return
        }
        fetchFromPort(ports[index]) { entry in
            if let entry = entry {
                completion(entry)
            } else {
                self.fetchFromPorts(ports, index: index + 1, completion: completion)
            }
        }
    }

    private func fetchFromPort(_ port: Int, completion: @escaping (BurnEntry?) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/stats") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data,
                  let decoded = try? JSONDecoder().decode(StatsResponse.self, from: data) else {
                completion(nil)
                return
            }
            completion(BurnEntry(date: Date(), stats: decoded, isConnected: true))
        }.resume()
    }
}
