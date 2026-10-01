from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "SarahIA/SarahIA/Services/VAICodeEngine.swift"
s = path.read_text(encoding="utf-8")

# Use Swift raw strings for regular expressions so \s, \S and quote classes are
# interpreted by NSRegularExpression rather than Swift string escaping.
s = s.replace('hasRegex("<html[^>]*\\slang\\s*=")', 'hasRegex(#"<html[^>]*\\slang\\s*="#)')
s = s.replace('hasRegex("<title>\\s*[^<]{2,}\\s*</title>")', 'hasRegex(#"<title>\\s*[^<]{2,}\\s*</title>"#)')
s = s.replace('hasRegex("<h1(?:\\s|>)[\\s\\S]*?</h1>")', 'hasRegex(#"<h1(?:\\s|>)[\\s\\S]*?</h1>"#)')

old_remote = '''        let remoteAssetPatterns = [
            "(?:src|poster)\\s*=\\s*[\\\\\"']https?://",
            "<link[^>]+href\\s*=\\s*[\\\\\"']https?://",
            "url\\(\\s*[\\\\\"']?https?://"
        ]'''
new_remote = '''        let remoteAssetPatterns = [
            #"(?:src|poster)\\s*=\\s*[\"']https?://"#,
            #"<link[^>]+href\\s*=\\s*[\"']https?://"#,
            #"url\\(\\s*[\"']?https?://"#
        ]'''
if old_remote in s:
    s = s.replace(old_remote, new_remote, 1)

# The first migration accidentally emitted literal line breaks inside ordinary
# Swift string literals. Replace them with explicit escaped newlines.
s = s.replace('result = "<!doctype html>\n" + result', 'result = "<!doctype html>\\n" + result')
s = s.replace('result.insert(contentsOf: "\n<meta charset=\\"utf-8\\">", at: range.upperBound)', 'result.insert(contentsOf: "\\n<meta charset=\\"utf-8\\">", at: range.upperBound)')
s = s.replace('result.insert(contentsOf: "\n" + viewport, at: range.upperBound)', 'result.insert(contentsOf: "\\n" + viewport, at: range.upperBound)')
s = s.replace('with: safetyCSS + "\n</head>"', 'with: safetyCSS + "\\n</head>"')

# Be explicit about Substring -> String conversion.
s = s.replace('with: opening.dropLast() + " lang=\\"fr\\">"', 'with: String(opening.dropLast()) + " lang=\\"fr\\">"')

# Safer internal-anchor test: CSS selectors can throw for unusual IDs.
s = s.replace(
    "const brokenLocalLinks = localLinks.filter(a => !document.querySelector(a.getAttribute('href'))).length;",
    "const brokenLocalLinks = localLinks.filter(a => { const href = a.getAttribute('href') || ''; const id = decodeURIComponent(href.slice(1)); return !id || !document.getElementById(id); }).length;"
)

required = [
    'hasRegex(#"<html[^>]*\\slang\\s*="#)',
    'result = "<!doctype html>\\n" + result',
    'String(opening.dropLast()) + " lang=\\"fr\\">"',
    'document.getElementById(id)'
]
for needle in required:
    if needle not in s:
        raise SystemExit(f"Missing syntax fix: {needle}")

path.write_text(s, encoding="utf-8")
print("Agentic web v6 Swift syntax fixed")
