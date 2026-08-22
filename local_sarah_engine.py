#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sarah IA - Moteur d'Intelligence Léger 100% Local (Python / Offline)
- Zéro dépendance externe, 100% stable et instantané.
- Analyse par mots-clés, règles, templates dynamiques et extraction d'entités.
- Gestion du coffre mémoire (Apprentissage & Rappel de faits).
- Calculateur mathématique sécurisé.
- Formatage compact des nombres (1K, 2M...).
"""

import re
import json
import random
import os
import sys
import math
from datetime import datetime
from typing import Optional, Dict, Any, List, Tuple

# Support UTF-8 sur terminal Windows
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass


def format_compact_number(number: int) -> str:
    """
    Formate un nombre de manière compacte :
    - < 1 000 : '950'
    - >= 1 000 et < 1 000 000 : '1.5K', '10K'
    - >= 1 000 000 : '2M', '1.2M'
    """
    abs_num = abs(number)
    sign = "-" if number < 0 else ""
    
    if abs_num >= 1_000_000:
        millions = abs_num / 1_000_000.0
        if millions.is_integer():
            return f"{sign}{int(millions)}M"
        formatted = f"{millions:.1f}"
        if formatted.endswith(".0"):
            formatted = formatted[:-2]
        return f"{sign}{formatted}M"
    elif abs_num >= 1_000:
        thousands = abs_num / 1_000.0
        if thousands.is_integer():
            return f"{sign}{int(thousands)}K"
        formatted = f"{thousands:.1f}"
        if formatted.endswith(".0"):
            formatted = formatted[:-2]
        return f"{sign}{formatted}K"
    else:
        return f"{number}"


class SarahLocalEngine:
    """Moteur conversationnel déterministe et ultra-rapide."""
    
    def __init__(self, memory_file: str = "sarah_local_memory.json"):
        self.memory_file = memory_file
        self.learned_memories: Dict[str, str] = self._load_memories()
        self.user_name: Optional[str] = self.learned_memories.get("_user_name")
        self.total_questions = int(self.learned_memories.get("_total_questions", "0"))
        self.total_conversations = int(self.learned_memories.get("_total_conversations", "1"))
        
        # Base de données de templates et règles
        self.jokes: List[str] = [
            "Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? Parce que sinon ils tombent dans le bateau ! 😂",
            "Que dit une imprimante dans l'eau ? J'ai du papier qui prend l'eau ! 🖨️",
            "Que fait une fraise sur un cheval ? Tagada, tagada ! 🍓🐎",
            "Que dit un informaticien quand il a froid ? Il ferme les fenêtres ! 💻🪟",
            "Pourquoi les oiseaux volent-ils vers le sud en hiver ? Parce que c'est trop long d'y aller à pied ! 🐦",
            "Quel est le comble pour un électricien ? De ne pas être au courant ! ⚡",
            "Deux grains de sable arrivent à la plage : « Chouette, c'est plein, on ne va pas pouvoir se poser ! » 🏖️",
            "Comment appelle-t-on un chat tout terrain ? Un cat-cat (4x4) ! 🐱"
        ]
        
        self.quotes: List[str] = [
            "« Le meilleur moyen de prédire l'avenir, c'est de le créer. » — Peter Drucker ✨",
            "« Ce n'est pas parce que les choses sont difficiles que nous n'osons pas, c'est parce que nous n'osons pas qu'elles sont difficiles. » — Sénèque 🌟",
            "« La simplicité est la sophistication suprême. » — Léonard de Vinci 💎",
            "« Tout ce que vous avez toujours voulu est de l'autre côté de la peur. » — George Addair 🚀",
            "« Chaque petite victoire quotidienne vous rapproche de votre grand objectif. Continuez ! » — Sarah 🌸"
        ]
        
        self.anecdotes: List[str] = [
            "🍎 Le saviez-vous ? Le logo original d'Apple représentait Isaac Newton assis sous un pommier !",
            "⚡ Le saviez-vous ? L'iPhone original (2007) avait 128 Mo de mémoire vive (RAM), soit 48 fois moins qu'un iPhone 14 !",
            "🌐 Le saviez-vous ? Le premier site Web de l'histoire a été mis en ligne au CERN le 6 août 1991.",
            "🍯 Le saviez-vous ? Le miel est le seul aliment qui ne périme jamais. Des pots vieux de 3000 ans retrouvés dans des tombes égyptiennes sont encore comestibles !"
        ]

    def _normalize(self, text: str) -> str:
        """Nettoie le texte (minuscules, suppression des accents et de la ponctuation superflue)."""
        text = text.lower().strip()
        replacements = {
            'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
            'à': 'a', 'â': 'a', 'ä': 'a',
            'î': 'i', 'ï': 'i',
            'ô': 'o', 'ö': 'o',
            'ù': 'u', 'û': 'u', 'ü': 'u',
            'ç': 'c', "'": ' ', "’": ' ', "-": ' '
        }
        for k, v in replacements.items():
            text = text.replace(k, v)
        # Supprimer la ponctuation
        text = re.sub(r'[?!.,;:/\\_()"\*]', ' ', text)
        return re.sub(r'\s+', ' ', text).strip()

    def _load_memories(self) -> Dict[str, str]:
        if os.path.exists(self.memory_file):
            try:
                with open(self.memory_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception:
                return {}
        return {}

    def _save_memories(self) -> None:
        try:
            self.learned_memories["_total_questions"] = str(self.total_questions)
            self.learned_memories["_total_conversations"] = str(self.total_conversations)
            if self.user_name:
                self.learned_memories["_user_name"] = self.user_name
            with open(self.memory_file, 'w', encoding='utf-8') as f:
                json.dump(self.learned_memories, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"⚠️ Erreur sauvegarde mémoire: {e}")

    def learn(self, trigger: str, response: str) -> str:
        """Enregistre une association dans le coffre mémoire."""
        clean_trig = self._normalize(trigger)
        self.learned_memories[clean_trig] = response.strip()
        self._save_memories()
        return f"🧠 C'est appris ! Dès que vous me parlerez de « {trigger.strip()} », je saurai répondre : « {response.strip()} »."

    def forget(self, target: str) -> str:
        """Supprime une entrée de mémoire."""
        clean_target = self._normalize(target)
        if clean_target in ["tout", "tous", "la memoire", "toute la memoire"]:
            self.learned_memories.clear()
            self._save_memories()
            return "🧹 Toute la mémoire locale a été réinitialisée !"
        
        if clean_target in self.learned_memories:
            del self.learned_memories[clean_target]
            self._save_memories()
            return f"🗑️ J'ai bien oublié « {target} »."
        return f"Je n'avais aucun souvenir enregistré pour « {target} »."

    def get_stats_summary(self) -> str:
        """Fournit les statistiques actuelles avec le formatage compact (1K, 2M...)."""
        conv_str = format_compact_number(self.total_conversations)
        msg_str = format_compact_number(self.total_questions)
        mem_count = len([k for k in self.learned_memories.keys() if not k.startswith("_")])
        mem_str = format_compact_number(mem_count)
        return (f"📊 **Statistiques Sarah IA** :\n"
                f"• Discussions actives : {conv_str}\n"
                f"• Questions & messages traités : {msg_str}\n"
                f"• Souvenirs dans le Brain Vault : {mem_str}")

    def _evaluate_math(self, raw_text: str) -> Optional[str]:
        """Tente d'évaluer une opération arithmétique simple en toute sécurité."""
        expr = raw_text.lower()
        for prefix in ["calcule", "combien font", "combien fait", "resultat de", "calcule moi", "racine de"]:
            expr = expr.replace(prefix, "")
        
        expr = expr.replace("x", "*").replace("×", "*").replace("÷", "/").replace(",", ".")
        # Garder uniquement les chiffres, opérateurs et parenthèses
        cleaned = re.sub(r'[^0-9\+\-\*\/\.\(\)\s]', '', expr).strip()
        if not cleaned or not any(op in cleaned for op in ['+', '-', '*', '/']):
            return None
        
        try:
            # Évaluation arithmétique contrôlée (sans builtins)
            result = eval(cleaned, {"__builtins__": None, "math": math}, {})
            if isinstance(result, (int, float)):
                if isinstance(result, float) and result.is_integer():
                    result = int(result)
                elif isinstance(result, float):
                    result = round(result, 4)
                return f"🧮 Résultat : **{cleaned} = {result}**"
        except Exception:
            return None
        return None

    def respond(self, query: str) -> str:
        """Génère la meilleure réponse en fonction des règles, intentions et templates."""
        raw = query.strip()
        if not raw:
            return "Je suis là ! Dites-moi ce que vous aimeriez savoir ou faire. 😊"
        
        self.total_questions += 1
        self._save_memories()
        
        norm = self._normalize(raw)
        
        # 1. Gestion du Prénom
        if norm.startswith("je m appelle ") or norm.startswith("mon nom est ") or norm.startswith("mon prenom est "):
            name_parts = raw.split()[3:] if norm.startswith("je m appelle ") else raw.split()[3:]
            name = " ".join(name_parts).strip()
            if name:
                self.user_name = name
                self._save_memories()
                return f"Enchantée {name} ! C'est un grand plaisir. Comment puis-je vous aider aujourd'hui ? ✨"
        
        if any(p in norm for p in ["comment je m appelle", "mon prenom", "mon nom", "qui suis je"]):
            if self.user_name:
                return f"Vous vous appelez **{self.user_name}** ! Je n'oublie jamais mes amis. 😊"
            return "Vous ne m'avez pas encore indiqué votre prénom ! Dites : « Je m'appelle [Votre prénom] » pour que je le retienne."
        
        # 2. Commandes d'apprentissage direct ("Apprends papa = au travail" ou "mémorise X : Y")
        if any(norm.startswith(p) for p in ["apprends ", "memorise ", "retient ", "enregistre "]):
            # Séparateurs possibles : '=', ':', 'c est', 'est'
            body = re.sub(r'^(apprends|memorise|retient|enregistre)\s+', '', raw, flags=re.IGNORECASE).strip()
            for sep in ["=", ":", "->", "=>", "c'est", "c est", "est"]:
                if sep in body:
                    parts = body.split(sep, 1)
                    if len(parts) == 2 and parts[0].strip() and parts[1].strip():
                        return self.learn(parts[0], parts[1])
            return "Pour m'apprendre quelque chose, dites par exemple : « **Apprends papa = il est au travail** » ou « **Mémorise code wifi : 123456** »."

        # 3. Oublier
        if norm.startswith("oublie ") or norm.startswith("efface "):
            target = re.sub(r'^(oublie|efface)\s+', '', raw, flags=re.IGNORECASE).strip()
            return self.forget(target)

        # 4. Consultation du coffre mémoire
        if any(p in norm for p in ["que sais tu", "tes souvenirs", "liste memoire", "ce que tu as appris", "coffre memoire"]):
            user_memories = {k: v for k, v in self.learned_memories.items() if not k.startswith("_")}
            if not user_memories:
                return "Mon coffre mémoire est vide pour l'instant. Dites par exemple : « Apprends [mot] = [réponse] » pour me former ! 🧠"
            items = "\n".join([f"• « **{k}** » ➔ {v}" for k, v in user_memories.items()])
            return f"🧠 **Souvenirs enregistrés dans mon coffre** :\n\n{items}"

        # 5. Matching du Coffre Mémoire (Recherche directe ou par mot-clé)
        for trig, fact in self.learned_memories.items():
            if trig.startswith("_"):
                continue
            if trig in norm or norm in trig:
                return f"🧠 D'après ce que j'ai appris : **{fact}**"

        # 6. Évaluation Mathématique
        math_res = self._evaluate_math(raw)
        if math_res:
            return math_res

        # 7. Date et Heure
        now = datetime.now()
        if any(p in norm for p in ["quelle heure", "l heure", "il est quelle heure", "donne moi l heure", "heure"]):
            return f"⏰ Il est exactement **{now.strftime('%Hh%M')}** (et {now.strftime('%S')} secondes)."
        
        if any(p in norm for p in ["date", "quel jour", "aujourd hui", "on est le combien"]):
            days_fr = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
            months_fr = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
            d_name = days_fr[now.weekday()]
            m_name = months_fr[now.month - 1]
            return f"📅 Nous sommes le **{d_name} {now.day} {m_name} {now.year}**."

        # 8. Météo locale / simulation
        if any(p in norm for p in ["meteo", "quel temps fait il", "temps dehors", "il pleut", "temperature"]):
            return "☀️ Il fait un temps agréable aujourd'hui ! Prévoyez une belle journée ensoleillée."

        # 9. Torche & Batterie (Simulation / Hardware feedback)
        if any(p in norm for p in ["allume la torche", "allumer la torche", "active la torche", "allume la lampe"]):
            return "🔦 La torche a été activée à pleine intensité !"
        if any(p in norm for p in ["eteins la torche", "eteindre la torche", "desactive la torche"]):
            return "🔦 La torche est désormais éteinte."
        if any(p in norm for p in ["batterie", "niveau de batterie", "pourcentage batterie"]):
            return "🔋 Votre appareil est à un niveau d'énergie optimal. Sarah IA fonctionne à pleine puissance locale !"

        # 10. Statistiques du Widget / Application
        if any(p in norm for p in ["statistiques", "stats", "widget", "combien de questions", "chiffres"]):
            return self.get_stats_summary()

        # 11. Salutations dynamiques
        if any(norm == g or norm.startswith(g + " ") for g in ["bonjour", "salut", "coucou", "hello", "bonsoir", "yo", "wesh", "re"]):
            hour = now.hour
            user_greeting = f" {self.user_name}" if self.user_name else ""
            if 5 <= hour < 12:
                return random.choice([
                    f"Bonjour{user_greeting} ! ☀️ Très belle matinée à vous. Comment puis-je vous aider ?",
                    f"Salut{user_greeting} ! En pleine forme pour commencer la journée ? Je suis à votre écoute.",
                    f"Coucou{user_greeting} ! Excellente matinée. Que faisons-nous aujourd'hui ?"
                ])
            elif 12 <= hour < 18:
                return random.choice([
                    f"Bonjour{user_greeting} ! 🌤️ Bon après-midi. Que puis-je faire pour vous aujourd'hui ?",
                    f"Salut{user_greeting} ! J'espère que votre journée se passe à merveille.",
                    f"Hello{user_greeting} ! Je suis toujours prête à vous assister !"
                ])
            else:
                return random.choice([
                    f"Bonsoir{user_greeting} ! 🌙 J'espère que vous avez passé une belle journée.",
                    f"Bonsoir{user_greeting} ! Que puis-je faire pour vous ce soir ?",
                    f"Salut{user_greeting} ! Toujours fidèle au poste, comment puis-je vous être utile ?"
                ])

        # 12. Humeur & État d'esprit
        if any(p in norm for p in ["ca va", "comment vas tu", "comment tu vas", "tu vas bien", "la forme"]):
            return random.choice([
                "Je vais à merveille, merci ! 😊 Prête et rapide comme l'éclair. Et vous, comment vous sentez-vous ?",
                "Tout roule pour moi ! 100% opérationnelle et à votre entière disposition. ✨",
                "Super bien ! Prête à répondre à toutes vos questions ou à exécuter vos ordres. 💪"
            ])

        # 13. Identité
        if any(p in norm for p in ["qui es tu", "tu es qui", "ton nom", "c est quoi ton nom", "qui t a cree"]):
            return ("👩🏻‍💼 Je suis **Sarah IA**, votre assistante intelligente ultra-rapide.\n"
                    "Je fonctionne à 100% en local sur votre appareil, sans temps d'attente ni coupure de connexion !")

        # 14. Blagues, Citations, Anecdotes
        if any(p in norm for p in ["blague", "raconte une blague", "fais moi rire", "humour"]):
            return random.choice(self.jokes)
        if any(p in norm for p in ["citation", "proverbe", "pensee", "motivation"]):
            return random.choice(self.quotes)
        if any(p in norm for p in ["anecdote", "saviez vous", "apprends moi quelque chose"]):
            return random.choice(self.anecdotes)

        # 15. Remerciements
        if any(p in norm for p in ["merci", "super", "genial", "parfait", "bravo", "top"]):
            return random.choice([
                "Avec grand plaisir ! Toujours là quand vous avez besoin de moi. 😊",
                "De rien ! N'hésitez pas si vous avez d'autres questions. ✨",
                "C'est un réel plaisir de vous aider ! 🌸"
            ])

        # 16. Aide & Capacités
        if any(p in norm for p in ["aide", "aide moi", "que sais tu faire", "que peux tu faire", "commandes", "fonctionnalites"]):
            return ("✨ **Voici tout ce que je peux faire en local instantanément** :\n\n"
                    "• 🧠 **Mémoire personnalisée** : « Apprends [mot] = [définition] »\n"
                    "• 🧮 **Calculs mathématiques** : « Calcule 45 * 12 »\n"
                    "• ⏰ **Heure & Date** : « Quelle heure est-il ? »\n"
                    "• 🔦 **Hardware** : « Allume la torche », « Niveau de batterie »\n"
                    "• 💬 **Culture & Humour** : « Raconte une blague », « Citation »\n"
                    "• 📊 **Widgets & Stats** : « Affiche mes statistiques »\n\n"
                    "Posez-moi n'importe quelle question !")

        # 17. Réponse par défaut chaleureuse et proactive
        return random.choice([
            f"Je vous ai bien compris ! Vous pouvez me demander de calculer quelque chose, d'enregistrer un souvenir avec « Apprends... » ou de vérifier l'heure et les réglages. 💡",
            f"C'est noté ! Je suis toujours à votre écoute. Souhaitez-vous que j'apprenne cette information ou avez-vous une autre demande ? 🧠",
            f"Entendu ! N'hésitez pas à me donner un ordre direct ou à me poser une question mathématique ou pratique. ✨"
        ])


if __name__ == "__main__":
    print("=" * 60)
    print("👩🏻‍💼 Sarah IA - Moteur d'Intelligence Léger 100% Local (Python)")
    print("Formatage des chiffres : 1.5K, 2M | Aucune dépendance externe requise.")
    print("Tapez 'quitter' pour sortir.")
    print("=" * 60)
    
    engine = SarahLocalEngine()
    
    # Démonstration du formatage compact
    demo_numbers = [850, 1500, 12300, 1000000, 2500000]
    formatted_demo = [f"{n} ➔ {format_compact_number(n)}" for n in demo_numbers]
    print("Exemples formatage compact : " + ", ".join(formatted_demo))
    print("-" * 60)
    
    # Test rapide non-interactif de validation
    test_queries = [
        "Bonjour",
        "Calcule 25 * 4",
        "Apprends papa = il est au travail",
        "Qui est papa ?",
        "Quelle heure est-il ?",
        "Statistiques"
    ]
    for q in test_queries:
        print(f"\n[Test] 👤 : {q}")
        print(f"[Test] 👩🏻‍💼 : {engine.respond(q)}")
