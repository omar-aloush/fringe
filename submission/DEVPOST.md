# Devpost submission draft — Fringe

> Working copy for the Devpost entry form. Verified against the official
> IEEE ClimateChain Devpost page on 2026-10-22: submissions close **Oct 25,
> 2026, 5:00 PM (UTC+3)**; required materials are the track-alignment
> statement, project description, 3–5 minute demo video, public repo link, and
> a working prototype.

## Track alignment statement

**Track 4 — Climate Data & Environmental Monitoring.** The track calls for
climate data verification platforms and IoT environmental monitoring; Fringe
is both. It is a climate data verification platform in the strict sense: every
number in the app resolves to a structured evidence record, every record is
hashed and anchored into the Bitcoin blockchain via OpenTimestamps, and any
user can verify the chain on-device in one tap. The environmental-monitoring
half is real: the app bundles and charts genuine Nevada Geodetic Lab GNSS time
series, and an ESP32 sensor streams live ground readings into the app over the
network. Fringe turns satellite-measured land motion — one of the most direct
physical signatures of drought and sea-level stress — into data people can
actually check.

## Project description (short)

Fringe makes satellite radar interferometry visible as living fringes on a
phone, and puts a verifiable evidence chain behind every number on screen.
Nine real events — spotlighting four major climate crisis flagships (California's
drought-compacted Central Valley, Norfolk's sinking coast compounding sea-level rise,
Jakarta's sinking megacity, and Mexico City's aquifer drainage) — rendered from
published physics and cited measurements. One tap shows the provenance of any figure;
another exports it as JSON; a third shows the Bitcoin block that anchors it against
retroactive alteration or greenwashing. Grounded AI answers questions using only
the cited evidence, and refuses to invent numbers.

## Judging criteria

### Climate Impact
Land subsidence is a quiet climate disaster: the Central Valley lost ~38 cm of
elevation at GNSS station P307 during the 2015–2016 drought as groundwater was
pumped out and aquifers compacted — much of it permanently, in the state that
grows a quarter of America's food under the SGMA water law passed because of
it. Norfolk is sinking 3.6–4.4 mm/yr (InSAR, 2015–2019) into the tail of
4.84 mm/yr relative sea-level rise at Sewells Point — a Navy and city planning
crisis in the Hampton Roads region. Fringe makes both crises visible,
understandable at three audience levels, and — uniquely — verifiable. The
impact path is honest: Fringe is a communication, provenance, and trust layer
over published measurements, not a new measurement pipeline, and it says so
everywhere.

### Innovation & Creativity
Three firsts for a hackathon demo: (1) real-time physics-modeled interferogram
rendering tuned to published measurements, with the MODELED distinction stated
on-screen instead of hidden; (2) an end-to-end data-integrity chain for climate
communication — SHA-256 evidence records → OpenTimestamps proofs → Bitcoin
block anchoring → on-device verification with a block-explorer handoff, where
the UI states precisely what the anchor proves and what it does not; (3)
"Ask this event" AI whose entire context is the exported evidence record, so
every answer is citable and out-of-context questions are refused. And the
honesty features are themselves creative: five geological events carry a
"climate connection: none claimed" note because that is what the evidence
supports.

### Technical Execution
Native SwiftUI app, offline-first, strict typing. Fringe displacement is
computed, never drawn: Mogi, Savage–Burford, and compaction models projected
onto a NISAR line-of-sight (37° incidence, ascending/descending geometries),
wrapped at λ/2 per band (L 23.8 cm, S 9.4 cm, C 5.55 cm). Ten bundled GNSS
time series are real NGL tenv3 data (IGS20). The OpenTimestamps parser in
Swift was written against the actual python-opentimestamps wire grammar and is
covered by a 16-test suite: physics math, record round-trips, digest checks,
proof parsing (pending and confirmed), and graceful AI degradation. The build
tooling (`Tools/anchor-evidence.py`, `Tools/make-gnss-bundle.py`) regenerates
the manifest and proofs from source data — the anchor chain is reproducible,
not hand-made.

### Practical Usefulness
For a journalist: export the JSON evidence record and cite the block anchor.
For a student: the three-level explainer and Lab make interferometry readable
without graduate coursework. For a planner or engineer: the dossiers separate
what the evidence shows from what it cannot tell us, with sources. For
scientists: per-item MEASURED/DERIVED/MODELED/LIVE labels and stated
limitations keep the app honest about its own rendering. Everything works in
airplane mode; the AI layer degrades to pre-generated interpretations without
connectivity rather than hallucinating.

### Presentation
The app is the pitch: a black mission console where rainbow fringes are the
only color, and where every tap is a receipt. The 3–5 minute video follows one
number — the Central Valley's −38 cm — from a dancing fringe, to its dossier,
to its JSON export, to its Bitcoin anchor, to an AI answer that cites it and
refuses to go beyond it.

## What is demonstrable today vs. future work

**Today (in the prototype):** all nine events with physics-modeled scenes and
published measurements; six-section dossiers for Central Valley and Norfolk;
evidence records with JSON export for every event; SHA-256 manifest +
OpenTimestamps proofs bundled and verified in-app (block confirmations pending
the ~48-hour Bitcoin window at submission time — the pending state is shown
honestly); grounded Q&A behind a configured gateway key, with pre-generated
interpretations as the offline default; ESP32 ground-station demo over local
network; the 16-test suite.

**Future work:** a raw Sentinel-1 processing pipeline (today's scenes are
physics renderings of published figures, labeled as such); continuous NISAR
ingestion; full cryptographic `.ots` verification inside the app (today:
digest recompute + proof parse + explorer link, with the `ots` CLI shown for
formal verification); multi-city coverage beyond the four climate crisis cases.

## Credits & data

- Buzzanga, B., Bekaert, D., Hamlington, B., Sangha, S. (2020). *Sustained
  Evolution of Coastal Subsidence in Norfolk and Virginia Beach, Virginia,
  From Sentinel-1 Interferometry*, GRL 47, e2020GL090013. Dataset:
  doi:10.25776/5yxq-w948.
- JPL/DWR Central Valley InSAR report (2015–2016 drought-era subsidence,
  >300 mm/yr near Corcoran); California SGMA (2014).
- Nevada Geodetic Laboratory GNSS time series (tenv3, IGS20 frame).
- NOAA tide gauge 8638610, Sewells Point, VA.
- OpenTimestamps (public calendar pool) and the Bitcoin blockchain.
- NASA/JPL Sentinel-1 and future NISAR mission parameters.

Team Fringe — built for the IEEE ClimateChain Hackathon, Track 4.
