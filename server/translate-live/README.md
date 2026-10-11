# Sarah Translate Live : réel hébreu → français, sans abonnement

**Objectif :** fournir à l'application Sarah un moteur de *traduction neuronale réelle* pour le flux d'une personne ou d'une vidéo en hébreu. Son iPhone capte l'audio avec Whisper, puis n'envoie **que de courtes transcriptions** à ce serveur local. Le serveur rend des phrases françaises, qui sont lues par la voix Yoann sur l'iPhone.

**Modèle :** [Helsinki-NLP/opus-mt-he-fr](https://huggingface.co/Helsinki-NLP/opus-mt-he-fr), annoncé **Apache 2.0**. Il ne remplace pas Whisper et ne fait pas de reconnaissance audio. Il ne gère ici que **he → fr**, pas « toutes les langues ». Qualité et latence à tester avant toute vente. Téléchargement Internet nécessaire la première fois ; ensuite les poids sont mis en cache sur ton serveur.

## Installation sur Debian avec Docker

Depuis le dossier `server/translate-live` du dépôt :

```bash
docker compose up --build -d
docker compose logs -f --tail 30
```

La première compilation installe PyTorch CPU et les dépendances et télécharge un modèle de traduction (plusieurs centaines de Mo), puis lance la traduction. Sur ton ancien serveur Debian, la RAM et la puissance CPU limitent la vitesse. Une connexion Internet est nécessaire pour le téléchargement initial, mais **pas pour les traductions suivantes**, si les modèles sont déjà présents.

Vérifier localement :

```bash
curl http://127.0.0.1:5000/health
curl -s -X POST http://127.0.0.1:5000/translate \
  -H 'Content-Type: application/json' \
  -d '{"q":"שלום, מה שלומך?","source":"he","target":"fr","format":"text"}'
```

Sur l'iPhone dans **Yoann → Serveur de traduction**, saisis `http://ADRESSE-IP-DE-TON-SERVEUR:5000` (sur le même Wi-Fi local). **N'ouvre pas le port 5000 vers Internet.** L'app n'envoie pas l'audio brut. Une fois les premiers poids téléchargés, aucun paiement ni nombre de caractères imposé par ce service ; il peut néanmoins y avoir des limitations de performance et de stockage.

Attention : port 5000 ouvert sur les appareils du LAN (aucune authentification). Utiliser exclusivement sur un réseau de confiance, et ajouter TLS/authentification avant accès distant ou distribution commerciale. Ce service est **un serveur volontairement local**, pas un serveur Internet sécurisé prêt à être commercialisé.

Le modèle et ses dépendances conservent leurs licences respectives. Voir `docs/VOICE_LICENSES.md` pour l'audit de commercialisation.
