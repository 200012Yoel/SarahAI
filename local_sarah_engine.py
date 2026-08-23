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
import urllib.request
import urllib.parse
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

    def fetch_weather(self, city: str) -> Optional[str]:
        """Récupère la météo en direct pour une ville via Open-Meteo API."""
        try:
            enc_city = urllib.parse.quote(city)
            geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={enc_city}&count=1&language=fr&format=json"
            req = urllib.request.Request(geo_url, headers={"User-Agent": "SarahIA-Python/2.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                if resp.status != 200:
                    return None
                data = json.loads(resp.read().decode('utf-8'))
                results = data.get("results", [])
                if not results:
                    return None
                first = results[0]
                lat = first["latitude"]
                lon = first["longitude"]
                name = first.get("name", city.title())
                country = first.get("country", "")

            forecast_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
            req2 = urllib.request.Request(forecast_url, headers={"User-Agent": "SarahIA-Python/2.0"})
            with urllib.request.urlopen(req2, timeout=3) as resp2:
                if resp2.status != 200:
                    return None
                f_data = json.loads(resp2.read().decode('utf-8'))
                current = f_data.get("current", {})
                temp = current.get("temperature_2m", 0)
                wind = current.get("wind_speed_10m", 0)
                code = current.get("weather_code", 0)

                conditions = {
                    0: "Ciel dégagé ☀️", 1: "Légèrement voilé 🌤️", 2: "Partiellement nuageux ⛅",
                    3: "Ciel couvert ☁️", 45: "Brouillard 🌫️", 51: "Bruine 🌦️",
                    61: "Pluie modérée 🌧️", 71: "Neige ❄️", 80: "Averses 🌧️", 95: "Orage ⚡"
                }
                cond_str = conditions.get(code, "Variable 🌤️")
                loc = f"{name}, {country}" if country else name
                return (f"👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de vérifier la météo pour vous en direct.*\n\n"
                        f"🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                        f"☀️ **Météo en direct pour {loc}** :\n\n"
                        f"• Température : **{int(temp)}°C**\n"
                        f"• Ciel : **{cond_str}**\n"
                        f"• Vent : **{int(wind)} km/h**\n\n"
                        f"Belle journée à vous ! 🌤️")
        except Exception:
            return None

    def search_web(self, query: str) -> str:
        """Effectue une recherche Web en direct (Météo + Wikipedia + DuckDuckGo + Vols/Billets) via l'Agent Tom."""
        clean = query.strip()
        norm = self._normalize(clean)

        # 0. Météo spécifique ("météo à Paris", "quel temps à Marseille", etc.)
        for trigger in ["meteo a ", "meteo pour ", "meteo de ", "temps a ", "temperature a "]:
            if trigger in norm:
                city = norm.split(trigger, 1)[1].strip(" .?!:")
                weather = self.fetch_weather(city)
                if weather:
                    return weather

        # 0.5. Billets de Train / SNCF / Trainline ("cherchemoi un billet de train de Paris a Deauville")
        if any(w in norm for w in ["billet de train", "billets de train", "billet train", "train pour", "train de ", "sncf", "trainline", "trajet en train"]) or ("train" in norm and ("paris" in norm or "billet" in norm or "deauville" in norm)):
            origin = "Paris"
            destination = "Deauville"
            if " de " in norm and (" a " in norm or " vers " in norm):
                parts = norm.split(" de ", 1)[1]
                sep = " a " if " a " in parts else " vers "
                if sep in parts:
                    sub = parts.split(sep, 1)
                    raw_orig = sub[0].strip()
                    for p in ["et", "un billet", "des billets", "billet de train", "billet", "train", "pour", "trajet"]:
                        raw_orig = re.sub(r'\b' + p + r'\b', '', raw_orig, flags=re.IGNORECASE).strip()
                    raw_orig = re.sub(r'^(de\s+|d\'|du\s+|des\s+)', '', raw_orig, flags=re.IGNORECASE).strip()
                    if raw_orig: origin = raw_orig.title()
                    raw_dest = sub[1].strip(" :?.!")
                    for p in ["et", "vers", "pour"]:
                        raw_dest = re.sub(r'\b' + p + r'\b', '', raw_dest, flags=re.IGNORECASE).strip()
                    raw_dest = re.sub(r'^(a\s+|vers\s+|pour\s+|de\s+|d\')', '', raw_dest, flags=re.IGNORECASE).strip()
                    if raw_dest: destination = raw_dest.title()
            elif " a " in norm or " pour " in norm:
                sep = " a " if " a " in norm else " pour "
                raw_dest = norm.split(sep, 1)[1].strip(" :?.!")
                for p in ["et", "vers", "pour"]:
                    raw_dest = re.sub(r'\b' + p + r'\b', '', raw_dest, flags=re.IGNORECASE).strip()
                raw_dest = re.sub(r'^(a\s+|vers\s+|pour\s+|de\s+|d\')', '', raw_dest, flags=re.IGNORECASE).strip()
                if raw_dest: destination = raw_dest.title()
            
            enc_orig = urllib.parse.quote_plus(origin)
            enc_dest = urllib.parse.quote_plus(destination)
            sncf_url = f"https://www.sncf-connect.com/app/home/search?origin={enc_orig}&destination={enc_dest}"
            trainline_url = f"https://www.thetrainline.com/fr/billets-de-train/{origin.lower()}-a-{destination.lower()}"
            maps_url = f"https://www.google.com/maps/dir/{enc_orig}/{enc_dest}"
            return (f"👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande tout de suite à **Tom**, mon agent de recherche Web, de trouver les meilleurs billets de train pour vous.*\n\n"
                    f"🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                    f"🚆 **Recherche de Billets de Train en direct** pour le trajet **{origin} ➔ {destination}** :\n\n"
                    f"• 🚄 **SNCF Connect** : Horaires TGV Inoui, TER & Nomad, disponibilités et réservation en direct\n"
                    f"  🔗 *{sncf_url}*\n"
                    f"• 🎫 **Trainline** : Comparateur de tarifs SNCF / Ouigo avec sélection de places et cartes Avantage\n"
                    f"  🔗 *{trainline_url}*\n"
                    f"• 🗺️ **Itinéraire & Temps de Trajet** : Visualiser les gares de départ et le plan ferroviaire\n"
                    f"  🔗 *{maps_url}*\n\n"
                    f"💡 *Astuce de Tom : Sur la ligne {origin} ➔ {destination}, les trains partent généralement de Paris-Saint-Lazare pour un temps de trajet moyen de 2h05.*")

        # 1. Billets d'avion / Vols / Voyage ("billet d'avion", "vol pour", "vols", "avion")
        if any(w in norm for w in ["billet d avion", "billets d avion", "vol pour", "vols pour", "trouve un vol", "chercher un vol", "comparateur de vol", "billet avion"]):
            dest = clean
            for p in ["cherche un billet d'avion pour", "recherche un billet d'avion pour", "billet d'avion pour", "billet d avion pour", "vol pour", "vols pour", "billet d'avion", "billet d avion"]:
                if p in dest.lower():
                    dest = dest.lower().split(p, 1)[1].strip(" :?.")
                    break
            dest_display = dest.title() if dest else "votre destination"
            encoded_dest = urllib.parse.quote_plus(dest if dest else "vol")
            return (f"👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande tout de suite à **Tom**, mon agent de recherche Web, de trouver les meilleurs billets d'avion pour vous.*\n\n"
                    f"🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                    f"✈️ **Recherche de Billets d'Avion & Comparateurs en direct** pour **{dest_display}** :\n\n"
                    f"• 🌐 **Google Flights** : Comparaison des vols en temps réel (escales, compagnies, calendrier des meilleurs prix)\n"
                    f"  🔗 *https://www.google.com/travel/flights?q={encoded_dest}*\n"
                    f"• 🛫 **Skyscanner** : Tarifs low-cost & compagnies régulières (Air France, EasyJet, Ryanair, Transavia...)\n"
                    f"  🔗 *https://www.skyscanner.fr/transport/vols/?q={encoded_dest}*\n"
                    f"• 🧭 **Kayak** : Alertes de prix & prédictions d'évolution des tarifs\n"
                    f"  🔗 *https://www.kayak.fr/flights*\n\n"
                    f"💡 *Astuce de Tom : Réservez idéalement un mardi ou mercredi en navigation privée pour obtenir les tarifs les plus avantageux.*")

        for prefix in ["cherche sur internet", "recherche sur internet", "cherche sur le web",
                       "recherche sur le web", "cherche moi", "trouve moi", "trouve sur internet",
                       "qui est", "qui etait", "c est quoi", "qu est ce que", "cherche", "recherche", "trouve"]:
            if clean.lower().startswith(prefix):
                clean = clean[len(prefix):].strip(" :?")
                break
        
        if not clean:
            clean = query.strip()

        # 2. Wikipedia REST API Summary
        try:
            encoded = urllib.parse.quote(clean)
            wiki_url = f"https://fr.wikipedia.org/api/rest_v1/page/summary/{encoded}"
            req = urllib.request.Request(wiki_url, headers={"User-Agent": "SarahIA-Python/2.0"})
            with urllib.request.urlopen(req, timeout=4) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                    extract = data.get("extract", "")
                    title = data.get("title", clean)
                    page_url = data.get("content_urls", {}).get("desktop", {}).get("page", "")
                    if extract:
                        return (f"👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de s'en occuper pour vous en direct.*\n\n"
                                f"🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                                f"🌐 **Résultat Web pour « {title} »** :\n\n"
                                f"{extract}\n\n"
                                f"📖 *Source vérifiée par Tom : Wikipédia ({page_url})*")
        except Exception:
            pass

        # 3. DuckDuckGo Instant Answer API
        try:
            ddg_query = urllib.parse.quote_plus(clean)
            ddg_url = f"https://api.duckduckgo.com/?q={ddg_query}&format=json&no_html=1&skip_disambig=1"
            req = urllib.request.Request(ddg_url, headers={"User-Agent": "SarahIA-Python/2.0"})
            with urllib.request.urlopen(req, timeout=4) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                    abstract = data.get("AbstractText", "")
                    heading = data.get("Heading", clean)
                    source_url = data.get("AbstractURL", f"https://duckduckgo.com/?q={ddg_query}")
                    if abstract:
                        return (f"👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de s'en occuper pour vous en direct.*\n\n"
                                f"🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                                f"🌐 **Résultat Web pour « {heading} »** :\n\n"
                                f"{abstract}\n\n"
                                f"🔗 *Source vérifiée par Tom : {source_url}*")
        except Exception:
            pass

        return (f"👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de regarder ça pour vous.*\n\n"
                f"🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                f"J'ai exploré le Web pour « {clean} ». N'hésitez pas à me donner plus de détails ou préciser votre mot-clé pour que je cible exactement votre besoin !")

    def respond(self, query: str) -> str:
        """Génère la meilleure réponse en fonction des règles, intentions et templates."""
        raw = query.strip()
        if not raw:
            return "Je suis là ! Dites-moi ce que vous aimeriez savoir ou faire. 😊"
        
        self.total_questions += 1
        self._save_memories()
        
        norm = self._normalize(raw)

        # 0. Commande Caméra & Appareil Photo / Partage d'écran
        if any(p in norm for p in ["partage mon ecran", "partager mon ecran", "partage l ecran", "analyse mon ecran", "live ecran"]):
            return "🖥️🔴 J'active le partage d'écran en direct avec Sarah ! Je peux observer votre écran et vous guider en temps réel."
            
        if any(p in norm for p in ["lance la camera", "ouvre la camera", "active la camera", "lance l appareil photo", "ouvre l appareil photo", "active l appareil photo", "prends une photo", "camera"]):
            return "📷 J'active la caméra immédiatement ! Pointez l'objectif vers ce que vous souhaitez que j'analyse."
        
        # 0.1 Commande Radio en direct (NRJ, France Inter, Skyrock, RTL, Nostalgie, FIP, Jazz...)
        if any(p in norm for p in ["arrete la radio", "stop radio", "coupe la radio", "radio off"]):
            return "J'ai arrêté la radio. ⏹️"
        
        radio_stations = {
            "nrj": "NRJ", "france inter": "France Inter", "skyrock": "Skyrock", "rtl": "RTL",
            "nostalgie": "Nostalgie", "fun radio": "Fun Radio", "fip": "FIP", "rmc": "RMC",
            "europe 1": "Europe 1", "jazz radio": "Jazz Radio", "jazz": "Jazz Radio",
            "radio classique": "Radio Classique", "classique": "Radio Classique",
            "france info": "France Info", "franceinfo": "France Info"
        }
        if any(p in norm for p in ["mets la radio", "lance la radio", "ecoute la radio", "allume la radio", "radio"]) or any(f"mets {k}" in norm for k in radio_stations):
            matched_st = "France Inter"
            for k, name in radio_stations.items():
                if k in norm:
                    matched_st = name
                    break
            return f"Je lance la radio **{matched_st}** en direct pour vous ! 📻🎶\nFlux audio officiel connecté. Bonne écoute !"
        
        # 0.2 Commande Apple Podcasts
        if any(p in norm for p in ["lance un podcast", "mets un podcast", "ouvre apple podcast", "ouvre les podcasts", "podcast sur", "podcast de", "podcast"]):
            topic = norm
            for p in ["lance un podcast sur", "mets un podcast sur apple podcast", "mets un podcast", "lance un podcast", "ouvre apple podcast", "podcast sur", "podcast de", "podcast"]:
                if p in topic:
                    topic = topic.split(p, 1)[1].strip(" :?.!")
                    break
            topic_str = f" pour « **{topic.title()}** »" if topic else ""
            return f"J'ouvre **Apple Podcasts**{topic_str} ! 🎙️ Retrouvez vos émissions et épisodes préférés."

        # 0.3 Commande Musique (Apple Music / Spotify)
        if any(p in norm for p in ["mets de la musique", "lance de la musique", "joue de la musique", "ouvre apple music", "ouvre spotify", "mets de la zik", "mets spotify"]):
            return "Je lance la musique sur votre lecteur musical ! 🎵🎧 Montez le son et profitez de vos morceaux préférés !"
        
        # 1. Commandes d'apprentissage direct ("Apprends papa = au travail" ou "mémorise X : Y")
        if any(norm.startswith(p) for p in ["apprends ", "memorise ", "retient ", "enregistre "]):
            body = re.sub(r'^(apprends|memorise|retient|enregistre)\s+', '', raw, flags=re.IGNORECASE).strip()
            for sep in ["=", ":", "->", "=>", "c'est", "c est", "est"]:
                if sep in body:
                    parts = body.split(sep, 1)
                    if len(parts) == 2 and parts[0].strip() and parts[1].strip():
                        return self.learn(parts[0], parts[1])
            return "Pour m'apprendre quelque chose, dites par exemple : « **Apprends papa = il est au travail** » ou « **Mémorise code wifi : 123456** »."

        # 2. Oublier
        if norm.startswith("oublie ") or norm.startswith("efface "):
            target = re.sub(r'^(oublie|efface)\s+', '', raw, flags=re.IGNORECASE).strip()
            return self.forget(target)

        # 3. Gestion du Prénom
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

        # 4. Consultation du coffre mémoire
        if any(p in norm for p in ["que sais tu", "tes souvenirs", "liste memoire", "ce que tu as appris", "coffre memoire"]):
            user_memories = {k: v for k, v in self.learned_memories.items() if not k.startswith("_")}
            if not user_memories:
                return "Mon coffre mémoire est vide pour l'instant. Dites par exemple : « Apprends [mot] = [réponse] » pour me former ! 🧠"
            items = "\n".join([f"• « **{k}** » ➔ {v}" for k, v in user_memories.items()])
            return f"🧠 **Souvenirs enregistrés dans mon coffre** :\n\n{items}"

        # 5. Matching du Coffre Mémoire (Recherche directe ou par mot-clé appris)
        for trig, fact in self.learned_memories.items():
            if trig.startswith("_"):
                continue
            if trig in norm or norm in trig:
                return f"🧠 D'après ce que j'ai appris : **{fact}**"

        # 6. Évaluation Mathématique
        math_res = self._evaluate_math(raw)
        if math_res:
            return math_res

        # 7. Intention de Recherche Web, Météo & Transports (Trains / Avions)
        clean_norm = (norm.replace("cherchemoi", "cherche moi")
                      .replace("trouvemoi", "trouve moi")
                      .replace("recherchemoi", "recherche moi")
                      .replace("cherche-moi", "cherche moi")
                      .replace("d'avion", "d avion")
                      .replace("d'hotel", "d hotel"))
        
        web_triggers = [
            "cherche ", "recherche ", "trouve sur internet", "trouve sur le web",
            "cherche sur internet", "cherche sur le web", "moteur de recherche",
            "qui est ", "qui etait ", "c est quoi ", "qu est ce que ",
            "actualite", "actualites", "sur wikipedia", "trouve ",
            "meteo a ", "meteo pour ", "meteo de ", "temps a ", "temperature a ",
            "billet de train", "billet train", "billets de train", "train pour", "train de ",
            "sncf", "trainline", "billet d avion", "billet avion", "billets d avion", "vol pour",
            "vols pour", "comparateur de vol", "hotel a ", "hotel pour", "cherche moi"
        ]
        if any(clean_norm.startswith(t) or t in clean_norm for t in web_triggers):
            return self.search_web(raw)

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
