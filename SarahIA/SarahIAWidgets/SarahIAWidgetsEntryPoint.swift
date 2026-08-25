#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

/// Point d'entrée officiel WidgetKit iOS 14+ (iPhone 14, 15, SE...)
/// Enregistre l'ensemble des 8 widgets officiels de Sarah IA dans la galerie iOS
@available(iOS 14.0, *)
@main
struct SarahIAWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        SarahConversationsWidget()
        SarahQuestionsWidget()
        SarahKnowledgeWidget()
        SarahStatusWidget()
        SarahTomVisionWidget()
        SarahMemoryWidget()
        SarahActivityWidget()
        SarahQuickActionsWidget()
    }
}
#endif
