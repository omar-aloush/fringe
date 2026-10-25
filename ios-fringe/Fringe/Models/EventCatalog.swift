import Foundation

/// Curated, offline case studies. Published figures live in `facts` with citations;
/// model parameters are chosen to reproduce those figures over each pass-pair window.
enum EventCatalog {
    static let svartsengi = DeformationEvent(
        id: "svartsengi",
        name: "Svartsengi",
        region: "Iceland",
        episode: "Inflation episode",
        kind: .uplift,
        latitude: 63.878,
        longitude: -22.432,
        model: .mogi(depthKm: 4.5, volumeKm3: 0.02),
        extentKm: 40,
        geometry: .ascending,
        windowDays: 120,
        rateUnit: .day,
        coseismicDay: nil,
        headline: "Magma is refilling the reservoir beneath the geothermal plant.",
        story: "Since October 2023 the ground at Svartsengi has swelled and dropped again and again. Each swell is magma pooling 4–5 km down. Each drop is that magma escaping sideways into a dike, and by January 2026 it had erupted nine times along the Sundhnúkur crater row. The town of Grindavík and the Blue Lagoon sit right on this bullseye.",
        facts: [
            PublishedFact(value: "3–4 mm/day", label: "Uplift rate at the onset of inflation in this volcanic system (Þorbjörn, January 2020)", source: "Icelandic Met Office, 2020"),
            PublishedFact(value: "4–5 km", label: "Depth of the pressure source from joint GNSS + InSAR inversion", source: "Parks et al., 2025"),
            PublishedFact(value: "9 eruptions", label: "Sundhnúkur crater row, December 2023 – January 2026", source: "Lanzi et al., EGU 2026"),
            PublishedFact(value: "Fast → slow", label: "Uplift is fastest right after each eruption, then eases as the reservoir refills", source: "Icelandic Met Office, 2025")
        ],
        seed: 11
    )

    static let mexicoCity = DeformationEvent(
        id: "mexico-city",
        name: "Mexico City",
        region: "Mexico",
        episode: "Aquifer subsidence",
        kind: .subsidence,
        latitude: 19.43,
        longitude: -99.08,
        model: .bowl(peakM: 0.30, sigmaKm: 6, aspect: 1.5, rotationDeg: 20),
        extentKm: 55,
        geometry: .ascending,
        windowDays: 360,
        rateUnit: .month,
        coseismicDay: nil,
        headline: "Pumping out groundwater is letting the old lakebed clay collapse.",
        story: "Mexico City is built on the soft clays of ancient Lake Texcoco. Pumping water from the aquifer below squeezes those clays like a sponge, so the city sinks unevenly and cracks pipes, metro lines and buildings. NISAR's first look in 2025–26 found neighborhoods dropping more than 2 cm every month.",
        facts: [
            PublishedFact(value: "> 2 cm/mo", label: "Sinking mapped by NISAR L-band, October 2025 – January 2026", source: "NASA / JPL, 2026"),
            PublishedFact(value: "~35 cm/yr", label: "Peak historical rates in the 1990s and 2000s", source: "NASA / JPL, 2026")
        ],
        seed: 23
    )

    static let jakarta = DeformationEvent(
        id: "jakarta",
        name: "Jakarta",
        region: "Indonesia",
        episode: "Coastal subsidence",
        kind: .subsidence,
        latitude: -6.12,
        longitude: 106.83,
        model: .bowl(peakM: 0.18, sigmaKm: 5, aspect: 2.0, rotationDeg: 5),
        extentKm: 50,
        geometry: .ascending,
        windowDays: 360,
        rateUnit: .year,
        coseismicDay: nil,
        headline: "Parts of North Jakarta are sinking faster than the sea is rising.",
        story: "Groundwater pumping and the weight of new buildings squeeze Jakarta's young coastal sediments together. Some northern districts already sit below sea level behind sea walls, which is one reason Indonesia is moving its capital to Nusantara on Borneo.",
        facts: [
            PublishedFact(value: "1–15 cm/yr", label: "Typical subsidence rates across the city", source: "Abidin et al., 2011, Natural Hazards"),
            PublishedFact(value: "20–28 cm/yr", label: "Local maximum rates in North Jakarta", source: "Abidin et al., 2011, Natural Hazards")
        ],
        seed: 37
    )

    static let kilauea = DeformationEvent(
        id: "kilauea",
        name: "Kīlauea",
        region: "Hawaiʻi",
        episode: "South flank creep",
        kind: .flank,
        latitude: 19.30,
        longitude: -155.15,
        model: .flank(peakM: 0.27, sigmaKm: 14, azimuthDeg: 155, verticalRatio: -0.3),
        extentKm: 70,
        geometry: .descending,
        windowDays: 1080,
        rateUnit: .year,
        coseismicDay: nil,
        headline: "Hawaiʻi's south flank is sliding into the Pacific.",
        story: "Kīlauea's south flank slowly creeps out to sea along a deep fault, pushed by magma forcing its way into the rift zones. Because the slide is mostly sideways, one radar look direction sees it much better than the other, so this scene uses a descending pass. In May 2018 the creep broke loose in a magnitude 6.9 earthquake.",
        facts: [
            PublishedFact(value: "up to ~10 cm/yr", label: "Seaward motion of the south flank", source: "USGS Hawaiian Volcano Observatory"),
            PublishedFact(value: "M 6.9", label: "South-flank earthquake, 4 May 2018", source: "USGS")
        ],
        seed: 41
    )

    static let sanAndreas = DeformationEvent(
        id: "san-andreas",
        name: "San Andreas",
        region: "California",
        episode: "Creeping section",
        kind: .faultSlip,
        latitude: 36.35,
        longitude: -120.85,
        model: .rupture(slipM: -0.25, depthKm: 12, strikeDeg: 317, lengthKm: 150),
        extentKm: 90,
        geometry: .ascending,
        windowDays: 3600,
        rateUnit: .year,
        coseismicDay: nil,
        headline: "Here the fault slides quietly instead of storing up a big quake.",
        story: "Between San Juan Bautista and Parkfield the San Andreas creeps steadily, shifting curbs, fences and winery walls a little every year. InSAR shows the creep as a sharp color step across the fault. Even over a decade the step is under one L-band fringe, so switch the sensor to C-band to measure it with a finer ruler.",
        facts: [
            PublishedFact(value: "~25 mm/yr", label: "Surface creep near the center of the creeping section", source: "Titus et al., 2006, BSSA"),
            PublishedFact(value: "Aseismic", label: "Steady creep between San Juan Bautista and Parkfield instead of stored strain", source: "USGS")
        ],
        seed: 53
    )

    static let campiFlegrei = DeformationEvent(
        id: "campi-flegrei",
        name: "Campi Flegrei",
        region: "Italy",
        episode: "Bradyseism",
        kind: .uplift,
        latitude: 40.827,
        longitude: 14.139,
        model: .mogi(depthKm: 3.5, volumeKm3: 0.0154),
        extentKm: 24,
        geometry: .ascending,
        windowDays: 360,
        rateUnit: .month,
        coseismicDay: nil,
        headline: "The ground under Pozzuoli is rising again.",
        story: "Campi Flegrei is a huge caldera just west of Naples, and roughly half a million people live inside it. Since 2005 the town of Pozzuoli has risen more than a meter in a slow swell geologists call bradyseism, while earthquake swarms rattle the homes above.",
        facts: [
            PublishedFact(value: "~25 mm/mo", label: "Ground uplift rate, December 2025", source: "INGV Osservatorio Vesuviano"),
            PublishedFact(value: "> 1 m", label: "Cumulative uplift at Pozzuoli since 2005", source: "INGV, RITE GNSS station")
        ],
        seed: 61
    )

    static let centralValley = DeformationEvent(
        id: "central-valley",
        name: "Central Valley",
        region: "California",
        episode: "Drought subsidence",
        kind: .subsidence,
        latitude: 36.10,
        longitude: -119.56,
        model: .bowl(peakM: 0.30, sigmaKm: 16, aspect: 2.2, rotationDeg: -50),
        extentKm: 140,
        geometry: .ascending,
        windowDays: 180,
        rateUnit: .month,
        coseismicDay: nil,
        headline: "Farms pumped so hard in the drought that the valley floor dropped.",
        story: "When surface water ran short in the 2012–2016 drought, growers drilled deeper wells. As the aquifers drained, the clay layers between them compacted for good. That permanently shrank underground water storage and buckled the canals that carry California's water. NASA radar caught some spots sinking nearly 5 cm a month.",
        facts: [
            PublishedFact(value: "~5 cm/mo", label: "Peak sinking during the 2014–2015 drought (“nearly 2 inches per month”)", source: "NASA JPL, Farr et al., 2015"),
            PublishedFact(value: "> 300 mm/yr", label: "Peak subsidence near Corcoran, Jan 2015 – Sep 2016", source: "NASA JPL / CA Dept. of Water Resources, InSAR"),
            PublishedFact(value: "−38 cm", label: "Ground drop measured by GNSS station P307 over the same window (bundled chart)", source: "Nevada Geodetic Lab, IGS20 daily solutions"),
            PublishedFact(value: "2014", label: "SGMA — California law requiring groundwater basins to reach sustainable yield", source: "CA Sustainable Groundwater Management Act")
        ],
        seed: 71
    )

    static let norfolk = DeformationEvent(
        id: "norfolk",
        name: "Norfolk",
        region: "Virginia, USA",
        episode: "Coastal subsidence",
        kind: .subsidence,
        latitude: 36.89,
        longitude: -76.29,
        model: .bowl(peakM: 0.019, sigmaKm: 9, aspect: 1.7, rotationDeg: -25),
        extentKm: 60,
        geometry: .ascending,
        windowDays: 1584,
        rateUnit: .year,
        coseismicDay: nil,
        headline: "The sea is rising while the land sinks — Norfolk faces both at once.",
        story: "Hampton Roads is one of the US metro areas most exposed to sea-level rise, and part of the exposure is the land itself. Sentinel-1 radar from 2015–2019 found Norfolk sinking about 4.4 mm a year on average, with hot spots near the waterfront. Half or more of the region's relative sea-level rise — 4.84 mm a year at the Sewells Point tide gauge since 1927 — comes from the ground going down, driven by groundwater pumping, settling sediments and the slow relaxation of land once pushed up by Ice Age ice sheets. The region's water utility is answering by refilling the aquifer: the SWIFT program treats wastewater and injects it back underground.",
        facts: [
            PublishedFact(value: "−4.4 ± 2.5 mm/yr", label: "Average subsidence of Norfolk, Mar 2015 – Jun 2019", source: "Buzzanga et al., 2020, GRL (Sentinel-1 InSAR)"),
            PublishedFact(value: "−3.6 ± 2.3 mm/yr", label: "Average subsidence across Hampton Roads", source: "Buzzanga et al., 2020, GRL (Sentinel-1 InSAR)"),
            PublishedFact(value: "4.84 mm/yr", label: "Relative sea-level rise at Sewells Point, 1927–2025", source: "NOAA tides & currents, station 8638610")
        ],
        seed: 97
    )

    static let turkiye = DeformationEvent(
        id: "kahramanmaras",
        name: "Kahramanmaraş",
        region: "Türkiye",
        episode: "M 7.8 earthquake",
        kind: .faultSlip,
        latitude: 37.25,
        longitude: 37.05,
        model: .rupture(slipM: 5, depthKm: 15, strikeDeg: 40, lengthKm: 300),
        extentKm: 380,
        geometry: .ascending,
        windowDays: 12,
        rateUnit: .coseismic,
        coseismicDay: 6,
        headline: "A 300 km tear across southern Türkiye, seen in a single pass pair.",
        story: "On 6 February 2023 the East Anatolian Fault ruptured in a magnitude 7.8 earthquake, and a magnitude 7.5 followed hours later. Radar pairs that span the quake show fringes packed tightly against the fault. Right at the trace, where the ground was torn apart, the signal dissolves into noise. L-band keeps a usable signal there far better than shorter wavelengths do.",
        facts: [
            PublishedFact(value: "M 7.8", label: "6 February 2023, East Anatolian Fault", source: "USGS"),
            PublishedFact(value: "~300 km", label: "Approximate length of the surface rupture", source: "USGS")
        ],
        seed: 83
    )

    static let all: [DeformationEvent] = [
        centralValley, norfolk, jakarta, mexicoCity, svartsengi, kilauea, sanAndreas, campiFlegrei, turkiye
    ]

    static let featured: DeformationEvent = centralValley

    static func event(id: String) -> DeformationEvent {
        all.first { $0.id == id } ?? featured
    }
}
