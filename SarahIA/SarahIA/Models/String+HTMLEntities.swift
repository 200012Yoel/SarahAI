import Foundation

// MARK: - Extension String : Décodage Robuste des Entités HTML (iOS 12.0+ à iOS 18.0+)
extension String {
    
    /// Décode proprement toutes les entités HTML brutes (ex: &#xF4;, &#xE0;, &quot;, &amp;, etc.)
    public func decodingHTMLEntities() -> String {
        guard self.contains("&") else { return self }
        
        var result = self
            // Entités XML/HTML de base
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            
            // Accents français courants
            .replacingOccurrences(of: "&eacute;", with: "é")
            .replacingOccurrences(of: "&egrave;", with: "è")
            .replacingOccurrences(of: "&ecirc;", with: "ê")
            .replacingOccurrences(of: "&agrave;", with: "à")
            .replacingOccurrences(of: "&ccedil;", with: "ç")
            .replacingOccurrences(of: "&ocirc;", with: "ô")
            .replacingOccurrences(of: "&icirc;", with: "î")
            .replacingOccurrences(of: "&ucirc;", with: "û")
            .replacingOccurrences(of: "&iuml;", with: "ï")
            .replacingOccurrences(of: "&euml;", with: "ë")
            .replacingOccurrences(of: "&ouml;", with: "ö")
            .replacingOccurrences(of: "&uuml;", with: "ü")
            .replacingOccurrences(of: "&auml;", with: "ä")
            .replacingOccurrences(of: "&Eacute;", with: "É")
            .replacingOccurrences(of: "&Egrave;", with: "È")
            .replacingOccurrences(of: "&Agrave;", with: "À")
            .replacingOccurrences(of: "&Ccedil;", with: "Ç")
        
        // 1. Décodage des entités hexadécimales (ex: &#xF4;, &#xE0;, &#x27;)
        if let regexHex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);", options: []) {
            let nsStr = result as NSString
            let matches = regexHex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let hexStr = nsStr.substring(with: match.range(at: 1))
                if let codePoint = UInt32(hexStr, radix: 16),
                   let scalar = UnicodeScalar(codePoint) {
                    let charStr = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: charStr)
                    }
                }
            }
        }
        
        // 2. Décodage des entités décimales (ex: &#244;, &#224;)
        if let regexDec = try? NSRegularExpression(pattern: "&#([0-9]+);", options: []) {
            let nsStr = result as NSString
            let matches = regexDec.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let decStr = nsStr.substring(with: match.range(at: 1))
                if let codePoint = UInt32(decStr, radix: 10),
                   let scalar = UnicodeScalar(codePoint) {
                    let charStr = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: charStr)
                    }
                }
            }
        }
        
        return result
    }
}
