import WidgetKit
import SwiftUI

@main
struct SarahIAWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SarahUsageStatsWidget()
        SarahStatusWidget()
        SarahMemoryWidget()
        SarahQuickVoiceWidget()
        SarahLastMessageWidget()
        SarahQuickActionsWidget()
        SarahSystemHealthWidget()
        SarahDailyTipWidget()
    }
}
