from pathlib import Path
p = Path('SarahIA/SarahIA/Services/MultiAgentCoordinator.swift')
s = p.read_text()
old = '''                    text: "💻 **Raphaël**

Aucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis produire le fichier réel.",
'''
new = '''                    text: "💻 **Raphaël**\\n\\nAucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis produire le fichier réel.",
'''
if old not in s:
    raise SystemExit('coordinator malformed string target missing')
p.write_text(s.replace(old, new, 1))
print('Coordinator publish message compile fix applied')
