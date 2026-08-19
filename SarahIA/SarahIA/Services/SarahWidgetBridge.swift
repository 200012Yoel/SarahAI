import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Pont de Contrôle Dynamique des Widgets iOS (WidgetKit Bridge) :
/// - Permet à Sarah de modifier les notes, le statut et l'apparence des widgets à la voix
public final class SarahWidgetBridge {
    
    public static let shared = SarahWidgetBridge()
    
    private let appGroupSuite = "group.com.sarahia.app"
    
    private init() {}
    
    public func updateWidgetData(note: String?, status: String?) {
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
        if let note = note {
            defaults.setValue(note, forKey: "sarah_widget_note")
        }
        if let status = status {
            defaults.setValue(status, forKey: "sarah_widget_status")
        }
        
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
