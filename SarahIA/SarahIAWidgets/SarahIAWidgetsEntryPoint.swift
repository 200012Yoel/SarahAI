import WidgetKit
import SwiftUI

@main
struct SarahIAWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SarahUsageStatsWidget()
        SarahMemoryWidget()
        SarahStatusWidget()
    }
}
