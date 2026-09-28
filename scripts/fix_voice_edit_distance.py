from pathlib import Path

p = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
s = p.read_text()
old = '''                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + cost
                )
'''
new = '''                current[j + 1] = min(
                    min(current[j] + 1, previous[j + 1] + 1),
                    previous[j] + cost
                )
'''
if old not in s:
    raise SystemExit('edit distance target missing')
p.write_text(s.replace(old, new, 1))
print('Voice fuzzy matching distance fixed')
