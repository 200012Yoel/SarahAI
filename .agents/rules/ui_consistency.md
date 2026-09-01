# Règle Permanente : Interface Universelle et Identique (iPhone 5s à iPhone 17+)

## Règle Absolue
Chaque fois que l'utilisateur demande d'améliorer, modifier, enrichir ou styliser l'interface utilisateur (UI/UX) :
1. **Identité Visuelle et Fonctionnelle Stricte** : L'interface doit être STRICTEMENT IDENTIQUE et synchronisée sur toutes les générations d'iPhone supportées (de l'iPhone 5s / iOS 12.0+ jusqu'à l'iPhone 17 Pro Max / iOS 18.0+ et versions futures).
2. **Dual-Implementation Synchronisée** :
   - Toute modification UI appliquée dans les vues modernes SwiftUI ([`ContentView.swift`](file:///c:/Users/Yoel%20Cohen/Downloads/Ikea%20iPhone/SarahIA/SarahIA/ContentView.swift), etc.) DOIT être immédiatement et fidèlement répercutée dans le contrôleur UIKit de secours ([`LegacyChatViewController.swift`](file:///c:/Users/Yoel%20Cohen/Downloads/Ikea%20iPhone/SarahIA/SarahIA/Views/LegacyChatViewController.swift)) et dans le simulateur web ([`index.html`](file:///c:/Users/Yoel%20Cohen/Downloads/Ikea%20iPhone/index.html)).
3. **Zéro Compromis Visuel** : Aucun composant, bouton, animation ou fonctionnalité ne doit être tronqué ou abandonné sur les anciens modèles (iPhone 5s, 6, SE1, 7, 8) ; le rendu doit être pixel-perfect et parfaitement fluide à 60 FPS sur 100% des appareils.
