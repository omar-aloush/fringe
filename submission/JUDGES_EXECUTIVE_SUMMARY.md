# Fringe — IEEE ClimateChain Hackathon (Track 4: Climate Data & Environmental Monitoring)
## Executive Submission Brief for Judges & Organizers

**Project Title:** Fringe — Cryptographic Radar Earth Observation & Climate Geodesy on iOS  
**Participant:** Omar Aloush  
**Track:** Track 4 — Climate Data & Environmental Monitoring  
**Live Web Showcase:** [https://fringe-earth.vercel.app](https://fringe-earth.vercel.app)  
**Public GitHub Repository:** [https://github.com/omar-aloush/fringe](https://github.com/omar-aloush/fringe)  
**Full 1080p Video Walkthrough:** [submission/fringe_demo_walkthrough.mp4](https://raw.githubusercontent.com/omar-aloush/fringe/main/submission/fringe_demo_walkthrough.mp4)  

---

### 1. Executive Summary & Problem Statement

Land subsidence is an insidious, irreversible climate crisis driven by extreme drought and sea-level rise:
- **Megadrought Aquifer Compaction:** During climate-driven droughts, catastrophic agricultural groundwater pumping causes subterranean pore-water pressure to collapse. Under lithostatic pressure, the fine-grained clay layers within aquifers compact permanently—destroying planetary freshwater storage capacity forever. In California’s Central Valley, the land sank over 38 cm at GNSS Station P307.
- **Compounded Coastal Sea-Level Rise:** In coastal regions like Norfolk, Virginia, ground subsidence (-4.4 mm/yr) multiplies global sea-level rise (+5.0 mm/yr), resulting in relative sea-level rise rates exceeding 9.4 mm/yr and threatening critical municipal infrastructure.
- **The Climate Trust Deficit (Greenwashing):** Environmental and carbon accounting data suffer from retrospective alteration and unverified baselines.

**Fringe solves both challenges:** It transforms complex Synthetic Aperture Radar Interferometry (InSAR) and continuous millimetric GPS data into intuitive visual interfaces on iOS, while anchoring every observation to the Bitcoin blockchain via OpenTimestamps to eliminate tampering.

---

### 2. Judging Criteria Alignment

| IEEE Criteria | Implementation in Fringe |
| :--- | :--- |
| **Climate Impact** | Directly monitors groundwater depletion and coastal subsidence across 4 global flagships (Central Valley, Norfolk, Jakarta, Mexico City). Translates satellite geodesy into 3 tiered audience perspectives (Public, Policy, Technical). |
| **Innovation & Creativity** | Combines spaceborne radar interferometry (NISAR 24cm L-band & Sentinel-1 5.6cm C-band) with continuous NSF GAGE GPS stations and real-time Apple Metal wavefront shaders in a native iOS environment. |
| **Technical Execution** | Fully native Swift 5.10 / SwiftUI / Metal codebase. Integrates SHA-256 Merkle tree hashing, binary OpenTimestamps `.ots` parsing, and continuous GNSS time-series regression. Zero legacy dependencies. |
| **Data Integrity & Honesty** | Non-repudiable audit trails anchored to Bitcoin Block #867,412. Explicitly distinguishes MEASURED vs. MODELED data and labels non-climate tectonic events with `"Climate connection: none claimed"`. |

---

### 3. Package Contents

This submission archive contains:
1. `ios-fringe/`: Complete, buildable native Swift & Metal Xcode 16 project.
2. `submission/screenshots/`: 10 Retina captures showcasing every step of the verified walkthrough.
3. `submission/DEVPOST.md`: Comprehensive narrative covering design decisions, challenges, and future roadmap.
4. `submission/DEMO_SCRIPT.md`: Precise 67-second shot-by-shot timeline breakdown.
5. `README.md` & `LICENSE`: Full architecture diagrams, scientific formulas, and official MIT License.

---
*Submitted for the IEEE ClimateChain Hackathon 2026.*
