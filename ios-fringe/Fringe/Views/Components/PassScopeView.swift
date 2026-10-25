import SwiftUI

/// Live radar-scope instrument: a beam sweeps the scope every few seconds, the
/// site blips at center, and the dashed track line shows the next pass heading
/// (ascending ≈348°, descending ≈192°). The countdown beside it is deterministic
/// repeat-cycle math from `MissionClock`.
struct PassScopeView: View {
    let event: DeformationEvent
    var beamPeriod: Double = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let beamDeg = (t.truncatingRemainder(dividingBy: beamPeriod) / beamPeriod) * 360
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 3
                let bearing = event.geometry.isAscending ? 348.0 : 192.0

                // Scope housing, range rings, crosshair.
                func ringPath(_ factor: CGFloat) -> Path {
                    let r = radius * factor
                    return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                }
                context.stroke(ringPath(1), with: .color(Theme.sage.opacity(0.45)), lineWidth: 1)
                for factor in [0.33, 0.66] {
                    context.stroke(ringPath(factor), with: .color(Theme.sage.opacity(0.16)), lineWidth: 1)
                }
                var cross = Path()
                cross.move(to: CGPoint(x: center.x - radius, y: center.y))
                cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                cross.move(to: CGPoint(x: center.x, y: center.y - radius))
                cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(cross, with: .color(Theme.sage.opacity(0.12)), lineWidth: 1)

                // Next-pass ground track through the site.
                var track = Path()
                let unit = CGPoint(x: sin(bearing * .pi / 180), y: -cos(bearing * .pi / 180))
                track.move(to: CGPoint(x: center.x - unit.x * radius, y: center.y - unit.y * radius))
                track.addLine(to: CGPoint(x: center.x + unit.x * radius, y: center.y + unit.y * radius))
                context.stroke(
                    track,
                    with: .color(Theme.accent.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 1.4, dash: [4, 4])
                )
                let apex = CGPoint(x: center.x + unit.x * radius, y: center.y + unit.y * radius)
                context.fill(
                    Path(ellipseIn: CGRect(x: apex.x - 3, y: apex.y - 3, width: 6, height: 6)),
                    with: .color(Theme.accent.opacity(0.9))
                )

                // Sweeping beam with a fading trail.
                for step in 0..<16 {
                    let angle = (beamDeg - Double(step) * 2.4) * .pi / 180
                    let alpha = step == 0 ? 0.85 : 0.3 * (1 - Double(step) / 16)
                    var ray = Path()
                    ray.move(to: center)
                    ray.addLine(to: CGPoint(
                        x: center.x + sin(angle) * radius,
                        y: center.y - cos(angle) * radius
                    ))
                    context.stroke(ray, with: .color(Theme.accent.opacity(alpha)), lineWidth: step == 0 ? 1.6 : 1)
                }

                // Site blip — flares as the beam crosses the track.
                let diff = angularDistance(beamDeg, bearing)
                let flare = max(0.0, 1.0 - diff / 40.0)
                let haloSize: CGFloat = 8 + CGFloat(flare) * 8
                let haloRect = CGRect(
                    x: center.x - haloSize / 2,
                    y: center.y - haloSize / 2,
                    width: haloSize,
                    height: haloSize
                )
                context.fill(Path(ellipseIn: haloRect), with: .color(Theme.accent.opacity(0.18 + flare * 0.3)))
                let coreRect = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: coreRect), with: .color(.white.opacity(0.85)))
            }
        }
        .background(Theme.canvas.opacity(0.7), in: Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Radar scope for \(event.name). Next pass track shown.")
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }
}

/// The full "Mission Clock" card for Event Detail: scope, live countdown,
/// upcoming passes, and the honesty note that this is modeled orbit math.
struct MissionClockCard: View {
    let event: DeformationEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MISSION CLOCK").kicker()
                Spacer()
                Text("MODELED ORBIT").kicker(Theme.sage.opacity(0.7))
            }

            HStack(spacing: 18) {
                PassScopeView(event: event)
                    .frame(width: 124, height: 124)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.stroke))

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let next = MissionClock.nextPass(for: event, after: context.date)
                    VStack(alignment: .leading, spacing: 3) {
                        if let next {
                            if MissionClock.isAcquiring(next, at: context.date) {
                                Text("ACQUIRING NOW")
                                    .kicker(Theme.amber)
                                Text("PASS IN PROGRESS")
                                    .font(.system(.title3, design: .monospaced, weight: .bold))
                                    .foregroundStyle(Theme.amber)
                            } else {
                                Text("NEXT PASS IN").kicker()
                                Text(MissionClock.countdown(from: context.date, to: next.date))
                                    .font(.system(size: 27, weight: .bold, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                                    .contentTransition(.numericText(value: context.date.timeIntervalSince1970))
                            }
                            Text("\(next.direction) · \(next.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.sage)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            TimelineView(.periodic(from: .now, by: 30)) { context in
                let passes = MissionClock.passes(for: event, after: context.date, count: 3)
                VStack(spacing: 0) {
                    ForEach(Array(passes.enumerated()), id: \.element.id) { index, pass in
                        if index > 0 { Divider().overlay(Theme.stroke) }
                        HStack(spacing: 12) {
                            Text(pass.isAscending ? "ASC" : "DSC")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 34, alignment: .leading)
                            Text(pass.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.text.opacity(0.85))
                            Spacer()
                            Text("+\(MissionClock.countdown(from: context.date, to: pass.date))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.sage)
                        }
                        .padding(.vertical, 7)
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Text("Pass times are modeled from NISAR's baseline 12-day repeat orbit (173 orbits per repeat, dawn–dusk crossings) — a planning estimate, not live telemetry.")
                .font(.caption2)
                .foregroundStyle(Theme.sage.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }
}
