# Fringe — Cryptographic Radar Earth Observation & Climate Geodesy (iOS)

[![Live Web Showcase](https://img.shields.io/badge/Live%20Showcase-fringe--earth.vercel.app-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://fringe-earth.vercel.app)
[![Platform: iOS 18+](https://img.shields.io/badge/Platform-iOS%2018%2B-blue?logo=apple&style=for-the-badge)](https://developer.apple.com/ios/)
[![Swift 5.10+](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&style=for-the-badge)](https://swift.org)
[![Track: IEEE ClimateChain 4](https://img.shields.io/badge/IEEE%20Track%204-Climate%20Monitoring-2ea44f?style=for-the-badge)](https://devpost.com)
[![Proof: Bitcoin OpenTimestamps](https://img.shields.io/badge/Immutability-Bitcoin%20OTS-F7931A?logo=bitcoin&style=for-the-badge)](https://opentimestamps.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-black?style=for-the-badge)](LICENSE)

> **Verifiable climate geodesy on iOS:** Fringe turns spaceborne Synthetic Aperture Radar Interferometry (InSAR) and continuous millimetric GPS into an intuitive, living visualization—anchoring environmental baseline data to the Bitcoin blockchain via OpenTimestamps to eliminate greenwashing and retroactive corporate tampering.
>
> 🌐 **Interactive Web Showcase:** [https://fringe-earth.vercel.app](https://fringe-earth.vercel.app)

---

## 🌍 The Climate Crisis: Invisible Ground Collapse

Land subsidence is a quiet, permanent climate catastrophe:
1. **Severe Megadroughts & Aquifer Skeleton Collapse:** During extreme climate-driven droughts, agricultural basins over-pump groundwater. As subterranean pore water pressure drops, the clay skeleton inside the aquifer permanently compacts under gravity. The freshwater storage capacity is destroyed forever. In California’s Central Valley, the ground sank over 30 cm during the 2015–2016 drought.
2. **Compounded Coastal Sea-Level Rise:** In coastal cities like Norfolk, Virginia, local land subsidence ($-4.4\text{ mm/yr}$) acts as a multiplier on global sea-level rise ($+5.0\text{ mm/yr}$), producing relative sea-level rise rates exceeding $9\text{ mm/yr}$ and accelerating sunny-day tidal flooding across critical naval and civilian infrastructure.
3. **The Data Trust Gap:** Environmental metrics and carbon accounting frequently suffer from retrospective alterations, greenwashing, and unverifiable baselines.

**Fringe solves both sides:** making satellite-measured land deformation visible to non-experts, while producing cryptographically verifiable proofs that the data has not been manipulated after the fact.

---

## ⚡ Core Scientific & Technical Architecture

```
 🛰️ Spaceborne Radar Satellites          📡 Ground Truth GNSS/GPS
  (Sentinel-1 C-band / NISAR L-band)       (NSF GAGE / Nevada Geodetic Lab)
                 │                                      │
                 ▼                                      ▼
       ┌──────────────────────────────────────────────────────┐
       │                 Fringe Geodetics Engine              │
       │   - Radar Line-of-Sight Projections (37° incidence)  │
       │   - Multi-Temporal Phase Wrapping: Δd = λ/(2 cos θ)  │
       │   - Real-time Metal Fragment Shaders (60 FPS)        │
       └──────────────────────────┬───────────────────────────┘
                                  │
                 ┌────────────────┴────────────────┐
                 ▼                                 ▼
   ┌───────────────────────────┐     ┌───────────────────────────┐
   │    Living Mission View    │     │   Cryptographic Anchor    │
   │  - 4 Climate Flagships    │     │  - SHA-256 Event Digests  │
   │  - Multi-band switching   │     │  - OpenTimestamps Proofs  │
   │  - Continuous GPS vectors │     │  - Bitcoin Block Headers  │
   │  - 3-Audience Dossiers    │     │  - One-tap JSON Export    │
   └─────────────┬─────────────┘     └─────────────┬─────────────┘
                 │                                 │
                 └────────────────┬────────────────┘
                                  ▼
                     ┌───────────────────────────┐
                     │     Grounded Local AI     │
                     │  - Strictly bounded RAG   │
                     │  - Zero hallucinations    │
                     │  - Full USGS/NASA sources │
                     └───────────────────────────┘
```

---

## 🛰️ Key Features

### 1. InSAR Radar Interferogram Rendering
Rather than optical photos (which are obscured by clouds), Fringe computes and renders living radar interferograms. Each rainbow color fringe represents half the radar wavelength:
$$\Delta d = \frac{\lambda}{2 \cos \theta}$$
- **NISAR L-band ($\lambda = 24\text{ cm}$):** NASA-ISRO mission parameters designed to penetrate vegetation canopies and track large agricultural displacement bowls.
- **Sentinel-1 C-band ($\lambda = 5.6\text{ cm}$):** High-sensitivity monitoring for urban infrastructure and slow creep.

### 2. Four Global Climate Flagships
- **Central Valley, California:** Megadrought aquifer compaction ($-30\text{ to }-38\text{ cm}$ vertical drop; California SGMA context).
- **Norfolk, Virginia:** Coastal land subsidence compounding sea-level rise into Sewells Point.
- **Jakarta, Indonesia:** Rapid coastal sinking ($-10\text{ to }-25\text{ cm/yr}$) driving capital relocation.
- **Mexico City:** Ancient lakebed compaction ($-20\text{ to }-30\text{ cm/yr}$) fracturing municipal water infrastructure.

### 3. Continuous Ground Truth (GNSS)
Direct overlay of millimetric 3-D displacement time series (East, North, Up) from active NSF GAGE / Nevada Geodetic Laboratory stations (e.g., Station P307 and P304 in California).

### 4. Anti-Greenwashing: Bitcoin OpenTimestamps Immutability
Every environmental event packet is serialized, hashed with SHA-256, and submitted to public Bitcoin calendar pools. The resulting `.ots` proof anchors the baseline observation to a permanent Bitcoin block header. Users can verify the proof on-device or export the raw JSON for external audits via standard CLI tools (`ots verify`).

### 5. Grounded On-Device AI Q&A
A specialized assistant answers user inquiries regarding deformation mechanisms. The model’s context is strictly bounded to the cryptographically hashed evidence packet—refusing to invent citations, numbers, or speculate beyond the verified record.

### 6. Interactive Interference Lab
A real-time sandbox powered by custom Apple Metal shaders. Users dynamically adjust radar wavelengths, incidence angles, and subsidence bowl dimensions to see how radar wave physics reconstructs crustal movement.

---

## 🔬 Scientific Honesty: Zero Greenwashing

In adherence to strict scientific rigor, Fringe explicitly distinguishes:
- **MEASURED:** Real GNSS time series and published InSAR datasets.
- **DERIVED:** Cumulative displacement vectors and rate calculations.
- **MODELED:** Physics-based interferogram simulations tuned to published peer-reviewed figures.
- **Non-Climate Tectonic Separation:** Geological events (such as the Mw 7.8 Turkey-Syria earthquake and Hawaii's Kīlauea volcano) carry an explicit label: `"Climate connection: none claimed"`, demonstrating that Fringe does not misattribute general geodynamics to climate change.

---

## 🛠️ Build & Development Setup

### Requirements
- macOS 14.5+ with Xcode 16+
- iOS 18.0+ Simulator or physical device

### Quick Start
```bash
# Clone the repository
git clone https://github.com/omar-aloush/fringe.git
cd fringe

# Open in Xcode
open ios-fringe/Fringe.xcodeproj
```

In Xcode, select the **Fringe** scheme and any **iOS 18+ Simulator** (e.g. iPhone 16 Pro / iPhone 18 Pro), then press `Cmd + R` to run.

### Running Test Suite
Fringe includes an automated XCTest suite covering geodesy projection math, OpenTimestamps binary wire format parsing, and SHA-256 Merkle tree verification:
```bash
xcodebuild test -project ios-fringe/Fringe.xcodeproj -scheme FringeTests -destination "platform=iOS Simulator,name=iPhone 16 Pro"
```

---

## 📁 Repository Structure

```
├── README.md                      # Comprehensive project documentation
├── LICENSE                        # MIT License
├── ios-fringe/                    # iOS Application Codebase
│   ├── Fringe.xcodeproj           # Xcode project configuration
│   ├── Fringe/                    # Swift 5.10 SwiftUI & Metal source code
│   │   ├── Models/                # Geodesy, InSAR, and Event data structures
│   │   ├── ViewModels/            # Observable state & tour choreography
│   │   ├── Views/                 # Radar Map, Dossiers, GNSS charts, Lab
│   │   ├── Services/              # OpenTimestamps, AI, and Geodesy pipelines
│   │   └── Shaders/               # Metal GPU interference compute kernels
│   ├── FringeTests/               # XCTest verification suite
│   ├── Hardware/                  # ESP32 micro-geodetic ground station sketch & wiring
│   └── Tools/                     # Python scripts for evidence hashing & Bitcoin anchoring
├── web/                           # Live Web Showcase (Vercel deployment)
│   ├── index.html                 # Apple/Linear-grade showcase with titanium chassis
│   ├── vercel.json                # Vercel deployment routing configuration
│   ├── walkthrough_preview.mp4    # Optimized walkthrough video loop
│   └── screenshots/               # 10 verified Retina presentation captures
└── submission/                    # IEEE Hackathon Submission Materials
    ├── DEVPOST.md                 # Devpost narrative & judging criteria alignment
    ├── DEMO_SCRIPT.md             # Timecoded 68s walkthrough shot list
    ├── fringe_demo_walkthrough.mp4# 1080p 60fps walkthrough video
    └── screenshots/               # 10 high-resolution Retina presentation captures
```

---

## 📚 Citations & Data Sources

- **Buzzanga et al. (2020):** *Sustained Evolution of Coastal Subsidence in Norfolk and Virginia Beach, Virginia, From Sentinel-1 Interferometry*, Geophysical Research Letters, [doi:10.25776/5yxq-w948](https://doi.org/10.25776/5yxq-w948).
- **NASA JPL / California DWR:** Central Valley InSAR Drought Subsidence Monitoring Reports (2015–2024); California Sustainable Groundwater Management Act (SGMA).
- **Nevada Geodetic Laboratory (NGL):** Continuous GNSS time series (tenv3 format, IGS20 reference frame).
- **NOAA Center for Operational Oceanographic Products:** Sewells Point Tide Station 8638610.
- **OpenTimestamps:** Bitcoin blockchain calendar attestation protocol.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
