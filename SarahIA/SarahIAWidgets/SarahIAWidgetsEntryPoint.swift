#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

@available(iOS 14.0, *)
struct SarahIAWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
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
#endif


