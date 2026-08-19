import Foundation
import UIKit

/// Compagnon Presse-Papier Intelligent (iOS - 100% Local)
public final class ClipboardCompanion {
    
    public static let shared = ClipboardCompanion()
    
    private init() {}
    
    public func getClipboardText() -> String? {
        return UIPasteboard.general.string
    }
    
    public func setClipboardText(_ text: String) {
        UIPasteboard.general.string = text
    }
}
