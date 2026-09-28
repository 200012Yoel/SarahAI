from pathlib import Path

path = Path('SarahIA/SarahIA/Services/MultiAgentCoordinator.swift')
text = path.read_text()
old = '''                    text: "💻 **Raphaël**

Aucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis produire le fichier réel.",
                    spokenText: "Aucun site réel n'est prêt. Je ne crée plus de faux dashboard de secours."
'''
new = '''                    text: "💻 **Raphaël**\\n\\nAucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis produire le fichier réel.",
                    spokenText: "Aucun site réel n'est prêt. Je ne crée plus de faux dashboard de secours."
'''
if old in text:
    text = text.replace(old, new, 1)
elif 'text: "💻 **Raphaël**\\n\\nAucun vrai site' not in text:
    raise SystemExit('coordinator malformed string target not found')
path.write_text(text)
print('Coordinator multiline string fixed')
