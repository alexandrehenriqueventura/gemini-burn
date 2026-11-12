import WidgetKit
import SwiftUI

@main
struct GeminiBurnWidget: Widget {
    let kind: String = "com.geminiburn.mac.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsTimelineProvider()) { entry in
            GeminiBurnWidgetView(entry: entry)
        }
        .configurationDisplayName("Gemini Burn")
        .description("Monitor de requisições, tokens e ritmo do Antigravity/Gemini.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
