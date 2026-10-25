# Fringe — InSAR for everyone, evidence you can verify

Fringe is a native iOS app that makes Earth's surface motion visible as living
radar fringes — and puts a verifiable evidence chain behind every number on
screen. Submitted to the IEEE ClimateChain Hackathon, **Track 4: Climate Data &
Environmental Monitoring**.

## The problem

Satellite radar interferometry (InSAR) measures ground motion to millimeter
precision, but it lives behind paywalls, paper supplements, and processing
pipelines nobody outside geodesy can read. Meanwhile, the cities sinking
fastest — from California's Central Valley to Hampton Roads, Virginia — are
making billion-dollar climate-adaptation decisions on this data.

**Two failure modes dominate public climate data:** numbers without provenance,
and AI that invents them. Fringe attacks both.

## What we built

- **Physics-based interferogram explorer** — nine real events (land subsidence,
  volcanoes, fault creep) rendered from Mogi, Savage–Burford, and compaction
  models projected onto a NISAR line-of-sight, one fringe = λ/2. Every scene is
  labeled **MODELED** — a physics rendering of published measurements, never
  presented as raw SAR pixels.
- **Evidence & Provenance, one tap away** — every event carries a structured
  evidence record: mission/dataset IDs, acquisition windows, GNSS station IDs,
  processing methods, per-item **MEASURED / DERIVED / MODELED / LIVE** labels,
  stated limitations, and sources with URLs. Exportable as JSON from the app.
- **Climate dossiers & flagships** — spotlighting four major climate crisis cases:
  flagship **Central Valley** (drought → groundwater pumping → aquifer compaction,
  −38 cm at GNSS station P307 during the 2015–2016 drought), **Norfolk / Hampton Roads**
  (−3.6 to −4.4 mm/yr subsidence compounding sea-level rise, InSAR 2015–2019, GRL 2020),
  **Jakarta** (sinking megacity), and **Mexico City** (aquifer drainage). Tectonic/volcanic
  events carry an honest "climate connection: none claimed" note — the honesty is the feature.
- **Bitcoin-anchored integrity** — every evidence record is SHA-256 hashed into
  a manifest at build time and time-stamped through OpenTimestamps. In the app:
  recompute the digest, compare it to the manifest, parse the `.ots` proof, and
  jump to the Bitcoin block on mempool.space. One tap, independent confirmation.
- **Grounded AI, two layers** — pre-generated interpretations (reliable for the
  demo, written from cited sources) plus "Ask this event" Q&A whose only
  context is that event's evidence record: answers must cite bundled facts,
  mark uncertainty, and refuse to invent numbers. Offline, the app says so
  instead of guessing.
- **Live ground station** — an ESP32 sensor streams real local readings over
  the network into the app: an IoT ground-truth companion, never a satellite
  proxy.

## Data sources

| Source | Used for |
| --- | --- |
| Published InSAR measurements (JPL/DWR Central Valley report; Buzzanga et al., *GRL* 2020, doi:10.1029/2020GL090013) | Event facts, model tuning, dossier numbers |
| Nevada Geodetic Lab GNSS time series (tenv3, IGS20) — bundled for P307, P304, UWEV, AHUP, BAKO, CIBG, CARL, POMM, REYK, FRUL | Real positional time-series charts |
| NOAA tide gauge 8638610 (Sewells Point) | Norfolk relative sea-level context |
| OpenTimestamps calendar pool + Bitcoin blockchain | Evidence-record anchoring |
| Sentinel-1 mission parameters (12-day repeat, C-band) | Acquisition timelines, pass clock |

## Build & run

1. Open the project in Xcode (iOS 18 SDK) and run the `Fringe` scheme on any
   iPhone simulator or device. No account, network, or API key is required —
   the app is offline-first; the interferograms, dossiers, GNSS charts, and
   integrity checks all work in airplane mode.
2. **Grounded Q&A (optional):** the "Ask this event" sheet activates only when
   an AI-gateway key is configured; without one it degrades gracefully and the
   pre-generated interpretations remain.
3. **ESP32 ground station (optional):** flash any ESP32 with the bundled
   firmware sketch and point the app at it on the local network.

## Verify the evidence chain yourself

```bash
# inside the repo — recompute hashes and show proof state
python3 Tools/anchor-evidence.py status

# formal verification of any bundled proof (pip install opentimestamps)
ots verify Fringe/Resources/Evidence/evidence-norfolk.ots
```

In-app: any event → **Evidence** chip → integrity section → the block-explorer
link. What this proves: the record is byte-for-byte unchanged since it was
anchored in Bitcoin block N. What it does not prove: the scientific accuracy of
the underlying measurements — the app says exactly this on screen.

## Honest scope

Demonstrable today: everything above. Future work: a raw Sentinel-1 processing
pipeline (scenes are physics renderings of published measurements), continuous
NISAR ingestion, and multi-city coverage. See `DEVPOST.md` for the full
criteria-by-criteria breakdown.
