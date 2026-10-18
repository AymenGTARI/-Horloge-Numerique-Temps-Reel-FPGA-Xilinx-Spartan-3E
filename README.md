# 🕐 Horloge Numérique Temps Réel — FPGA Xilinx Spartan-3E

Implémentation en VHDL d'une horloge numérique temps réel avec affichage VGA sur carte **Xilinx Spartan-3E Starter Kit**.  
L'heure est affichée au format **HH:MM** sur un moniteur via le port VGA (640×480 @ 60 Hz), avec possibilité de réglage manuel via des boutons physiques.

---

## 📁 Structure du projet

```
.
├── horloge_complete.vhd   # Top-level : instancie tous les blocs
├── div.vhd                # Diviseur de fréquence → tick 1 seconde + LED blink
├── bloc2.vhd              # Compteur hh:mm:ss + gestion boutons
├── clk_div_vga.vhd        # Diviseur 50 MHz → 25 MHz pour pixel clock VGA
├── vga_affichage.vhd      # Contrôleur VGA + rendu bitmap HH:MM
└── imp.ucf                # Contraintes de placement/routage (pin assignment)
```

---

## 🏗️ Architecture

```
clk (50 MHz)
    │
    ├──► div ──────────────► tick_1s ──► bloc2 ──► min[5:0]
    │         └──► led                         └──► heure[4:0]
    │                                                   │
    └──► clk_div_vga ──► clk_25 (25 MHz)               │
                              │                         │
                              └──► vga_affichage ◄──────┘
                                       │
                              hsync / vsync / rgb
```

| Composant | Rôle |
|---|---|
| `div` | Divise 50 MHz pour générer un tick d'1 seconde et fait clignoter une LED |
| `bloc2` | Compte les secondes, minutes, heures (00:00 → 23:59) et gère les 4 boutons de réglage |
| `clk_div_vga` | Divise 50 MHz par 2 pour obtenir le pixel clock VGA (25 MHz) |
| `vga_affichage` | Génère HSYNC/VSYNC, lit une ROM de police bitmap 8×16 px et affiche HH:MM centré sur fond bleu |

---

## 🖥️ Affichage VGA

- **Résolution :** 640×480 @ 60 Hz (pixel clock 25 MHz)
- **Format :** HH:MM centré à l'écran
- **Police :** bitmap 8×16 px, mise à l'échelle ×8 → chiffres de 64×128 px
- **Couleurs :** texte blanc `(111,111,111)` sur fond bleu foncé `(000,000,010)`
- **DAC couleur :** 3 bits par canal (R, G, B) — résistances de pondération intégrées à la carte

---

## 🎮 Boutons de réglage

| Bouton | Broche | Fonction |
|---|---|---|
| `btn_min_up` | P48 | Incrémente les minutes |
| `btn_min_down` | P69 | Décrémente les minutes |
| `btn_h_up` | P47 | Incrémente les heures |
| `btn_h_down` | P41 | Décrémente les heures |
| `rst` | P38 | Remet l'horloge à 00:00 |

La détection de **front montant** (edge detection) évite les rebonds et les incréments multiples.

---

## ⚙️ Outils & Environnement

| Outil | Version |
|---|---|
| Langage | VHDL-93 |
| Synthétiseur | Xilinx XST |
| Environnement | Xilinx ISE Design Suite 14.x |
| Carte cible | Xilinx Spartan-3E Starter Kit |
| FPGA | XC3S500E |
| Oscillateur | 50 MHz |

---

## 🚀 Utilisation

1. Ouvrir Xilinx ISE et créer un nouveau projet ciblant **XC3S500E**.
2. Ajouter tous les fichiers `.vhd` et le fichier `imp.ucf`.
3. Lancer **Synthesize → Implement Design → Generate Programming File**.
4. Programmer la carte via **iMPACT** avec le fichier `.bit` généré.
5. Brancher un moniteur VGA et alimenter la carte.

---

## 📌 Contraintes UCF (pin assignment)

| Signal | Broche |
|---|---|
| `clk` | P54 |
| `rst` | P38 |
| `led` | P15 |
| `vga_hsync` | P39 |
| `vga_vsync` | P35 |
| `vga_r[2:0]` | P67, P68, P70 |
| `vga_g[2:0]` | P50, P51, P52 |
| `vga_b[1:0]` | P43, P44 |

---

## 📚 Concepts mis en œuvre

- Conception numérique synchrone et architecture modulaire en VHDL
- Génération de signaux de synchronisation VGA from scratch
- ROM de police bitmap et rendu pixel par pixel
- Diviseur de fréquence et gestion du domaine d'horloge
- Détection de front montant pour entrées asynchrones
- Résolution de contraintes de synthèse XST (opérateurs arithmétiques, puissances de 2)
- Placement/routage et pin assignment (fichier UCF)

---

## 👤 Auteur

Projet académique réalisé dans le cadre d'un cours de conception numérique sur FPGA.
