# Traduction en direct (Yoann · Translate Live)

## Usage visé

Poser l'iPhone devant la télévision (chaîne israélienne, chaîne américaine…) et lire la traduction française en sous-titres, **sans écouteurs**.

Ouvre **Sarah → Outils → Yoann · Translate Live**, choisis la langue entendue (Hébreu, Anglais US/UK) et la langue de traduction (Français), puis **Démarrer**. L'écran reste allumé tant que la traduction tourne.

## Fonctionnement

```
micro iPhone → Whisper Medium (sur l'iPhone) → Traduire d'Apple (sur l'iPhone) → sous-titres
```

| Paire | Reconnaissance | Traduction |
| --- | --- | --- |
| Anglais → français | Whisper transcrit l'anglais | Traduire d'Apple EN→FR |
| Hébreu → français, iOS avec pack hébreu | Whisper transcrit l'hébreu | Traduire d'Apple HE→FR |
| Hébreu → français, iOS sans pack hébreu | Whisper traduit la parole hébraïque en anglais | Traduire d'Apple EN→FR |
| N'importe quelle langue → anglais | Whisper traduit directement | — |

Le moteur est choisi automatiquement au démarrage (`LanguageAvailability`). La ligne du bas indique ce que Whisper a compris (l'hébreu, ou son relais anglais).

Il n'y a plus de traduction par Qwen3 0.6B : ce mini-modèle inventait des phrases. Qwen reste utilisé uniquement par le chat de Sarah.

## Réglages importants

- **Mode « Sous-titres seulement » (par défaut)** : rien n'est lu à voix haute. Le micro fonctionne en mode `measurement`, sans le traitement « appel téléphonique » (annulation d'écho, réduction de bruit, gain automatique) qui atténuait fortement le son lointain d'une télé.
- **Voix dans les écouteurs / sur le haut-parleur** : options facultatives, la traduction est aussi lue par la voix neuronale.
- **Découpage audio** : Whisper reçoit des passages de 2,5 à 7 secondes coupés sur une vraie pause. Le seuil de pause suit le bruit de fond de la télé (plancher adaptatif), au lieu d'un seuil fixe qui ne voyait jamais de silence.
- **Filtres** : musique, boucles de répétition et « génériques » inventés par Whisper (« Thanks for watching », « Sous-titrage… ») sont ignorés.

## Première utilisation

Traduire d'Apple doit avoir ses langues téléchargées (une seule fois, connexion nécessaire) : **Réglages › Apps › Traduire › Langues téléchargées** → Anglais et Français (et Hébreu s'il est proposé). iOS 18 minimum.

## Modèles embarqués dans l'IPA

- `WhisperModels/ggml-medium-q5_0.bin` (≈ 540 Mo) : traduction en direct. Si absent, l'app retombe sur `ggml-base`.
- `WhisperModels/ggml-base.bin`, `ggml-tiny.bin` : chat vocal de Sarah.

## Serveur personnel (facultatif)

Un serveur compatible LibreTranslate peut être indiqué dans ⚙️ (voir [server/translate-live/README.md](../server/translate-live/README.md)). Laisser vide pour la traduction d'Apple sur l'iPhone.

## À vérifier sur iPhone

Ces changements n'ont pas pu être testés sur un appareil : vérifier le délai réel, la qualité sur une vraie émission en hébreu et en anglais, et la tenue sur une longue durée (chaleur, batterie).
