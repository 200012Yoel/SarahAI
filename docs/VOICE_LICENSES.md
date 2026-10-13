# Sarah IA · Voix locales et licence commerciale

## Architecture embarquée

- **STT (compréhension)** : OpenAI Whisper Base multilingue, via whisper.cpp v1.9.4.
- **TTS (lecture)** : Supertonic 3, exécuté sur iPhone par sherpa-onnx (iOS static XCFramework).
- **PCM** : AVAudioPlayer / AVAudioSession d'Apple uniquement pour la capture et la sortie audio. Ils ne produisent pas les voix.
- **Pas d'API de synthèse vocale Apple** : AVSpeechSynthesizer et SFSpeechRecognizer ont été retirés des chemins de reconnaissance et de lecture du chat, des façades et du module de traduction d'appel.
- **Pas d'API cloud pour la lecture** : l'IPA embarque les poids du TTS.
- **Vitesse** : la synthèse tourne sur une file de travail. Les générations périmées sont annulées logiquement avant lecture. Le premier chargement du modèle reste plus lent.

## Profils vocaux

| Agent | Modèle | Speaker | Timbre |
| --- | --- | --- | --- |
| Sarah | Supertonic 3 | 0 | F1, féminin |
| Ethel | Supertonic 3 | 1 | F2, féminin |
| Raphaël (identifiant historique Esther) | Supertonic 3 | 5 | M1, masculin |
| Tom | Supertonic 3 | 6 | M2, masculin |
| Yohan | Supertonic 3 | 7 | M3, masculin |
| Nathan | Supertonic 3 | 8 | M4, masculin |

**Langues** : français et anglais, selon la sélection. Attention : **Supertonic 3 ne prend pas en charge l'hébreu**. Whisper transcrit l'hébreu, mais le texte hébreu ne doit pas être prononcé avec un faux accent via le modèle français. La synthèse en hébreu doit attendre un modèle autorisant explicitement la revente et un test qualité.

## Licences à préserver dans l'application commerciale

| Composant | Licence | Vente possible ? | Obligations |
| --- | --- | --- | --- |
| Modèle [Supertonic 3](https://huggingface.co/Supertone/supertonic-3) | **OpenRAIL-M** | Oui, sous réserve des restrictions d'usage | Conserver la licence complète et les notices, appliquer les restrictions d'usage, avertir les bénéficiaires |
| Runtime [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Apache-2.0 | Oui | Conserver LICENSE / notices / attributions |
| ONNX Runtime | MIT | Oui | Conserver copyright et licence |
| Whisper (poids OpenAI) | MIT | Oui | Conserver licence OpenAI Whisper |
| whisper.cpp | MIT | Oui | Conserver licence |
| Alternatives [Kokoro 82M](https://huggingface.co/hexgrad/Kokoro-82M) | Apache-2.0 | Oui | Conserver licence, vérifier toute autre composante vocale |
| Piper français MLS | Corpus CC BY 4.0 | Avec attribution vérifiée | Attribution requise ; licences des phonémiseurs à vérifier |

**Ne pas annoncer "sans licence".** Il n'y a aucun abonnement ni achat de licence commerciale séparée pour les modèles sélectionnés, mais les licences **doivent être respectées**, même pour un produit payant. Le moteur Supertonic 3 n'est **pas** sous Apache-2.0 : le confondre avec son wrapper serait une erreur juridique.

L'IPA doit inclure les notices complètes de Supertonic, sherpa-onnx et ONNX Runtime sous `NeuralVoices/Supertonic3/`. La distribution devra aussi mentionner les composants tiers dans les mentions légales / la page À propos.

## À tester avant fusion / commercialisation

1. Faire compiler `SarahIA` avec Xcode 27 et le paquet sherpa-onnx 1.13.8. 
2. Vérifier sur iPhone réel (iOS 16.2+) chaque voix, la première génération, les interruptions, le micro, le Bluetooth et le retour en arrière-plan.
3. Confirmer la taille finale de l'IPA (~129 Mo d'archive TTS à télécharger au build, ensuite modèle décompressé), RAM et temps de chargement.
4. Confirmer que les voix français/anglais se distinguent réellement et que le texte hébreu est clairement signalé comme non vocalisé.
5. Relire les restrictions OpenRAIL-M avec les conditions actuelles avant diffusion à des clients.

⚠️ L'ajout de sources et le contrôle statique ne sont **pas** une preuve de fonctionnement sur appareil. Ne pas fusionner tant que la compilation et les essais vocaux ne sont pas passés.
