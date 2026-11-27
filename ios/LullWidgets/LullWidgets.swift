import WidgetKit
import SwiftUI
import ActivityKit

@main
struct LullWidgetBundle: WidgetBundle {
    var body: some Widget {
        LampWidget()
        QuickCalmWidget()
        SessionLiveActivity()
    }
}

// MARK: - timeline (the lamp's colours, saved by the app)

struct PaletteEntry: TimelineEntry {
    let date: Date
    let palette: LullShared.Palette
}

struct PaletteProvider: TimelineProvider {
    func placeholder(in context: Context) -> PaletteEntry { PaletteEntry(date: .now, palette: .init()) }
    func getSnapshot(in context: Context, completion: @escaping (PaletteEntry) -> Void) {
        completion(PaletteEntry(date: .now, palette: LullShared.palette))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PaletteEntry>) -> Void) {
        completion(Timeline(entries: [PaletteEntry(date: .now, palette: LullShared.palette)], policy: .never))
    }
}

// MARK: - drawing a little lava lamp

struct MiniLamp: View {
    let p: LullShared.Palette
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let hot = Color(hex: p.hot), cool = Color(hex: p.cool)
            ZStack {
                // glow behind the lamp
                Circle().fill(hot.opacity(0.35)).frame(width: w * 0.9).blur(radius: w * 0.2).offset(y: h * 0.08)
                VStack(spacing: 0) {
                    // cap
                    Trapezoid(topRatio: 0.45).fill(LinearGradient(colors: [.gray.opacity(0.9), .white.opacity(0.8), .gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 0.3, height: h * 0.14)
                    // glass with lava
                    ZStack {
                        Trapezoid(topRatio: 0.62, flip: true)
                            .fill(LinearGradient(colors: [Color(hex: p.liqTop), Color(hex: p.liqBot)], startPoint: .top, endPoint: .bottom))
                        blob(hot, cool, size: w * 0.17, x: -w * 0.03, y: -h * 0.12)
                        blob(hot, cool, size: w * 0.11, x: w * 0.06, y: h * 0.0)
                        blob(hot, cool, size: w * 0.2, x: -w * 0.01, y: h * 0.14)
                        Trapezoid(topRatio: 0.62, flip: true).stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .clipShape(Trapezoid(topRatio: 0.62, flip: true))
                    .frame(width: w * 0.42, height: h * 0.5)
                    // base
                    Trapezoid(topRatio: 0.6).fill(LinearGradient(colors: [.gray.opacity(0.7), .white.opacity(0.85), .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 0.46, height: h * 0.22)
                }
            }
            .frame(width: w, height: h)
        }
    }
    private func blob(_ hot: Color, _ cool: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [hot, cool], center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.6))
            .frame(width: size, height: size)
            .shadow(color: hot.opacity(0.7), radius: size * 0.25)
            .offset(x: x, y: y)
    }
}

/// A trapezoid; `topRatio` is the top width relative to the bottom (or the reverse when flipped).
struct Trapezoid: Shape {
    var topRatio: CGFloat
    var flip = false
    func path(in r: CGRect) -> Path {
        var p = Path()
        let narrow = r.width * topRatio, inset = (r.width - narrow) / 2
        if flip {   // narrow at the top
            p.move(to: CGPoint(x: r.minX + inset, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        } else {    // the same shape, used for the cap and base
            p.move(to: CGPoint(x: r.minX + inset, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        }
        p.closeSubpath(); return p
    }
}

// MARK: - Home Screen / StandBy lamp

struct LampWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LullLamp", provider: PaletteProvider()) { entry in
            LampWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(hex: entry.palette.liqTop), .black], startPoint: .top, endPoint: .bottom)
                }
                .widgetURL(URL(string: "lull://open"))
        }
        .configurationDisplayName("Lava lamp")
        .description("Your lamp, in its current colours.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LampWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PaletteEntry
    var body: some View {
        if family == .systemMedium {
            HStack(spacing: 14) {
                MiniLamp(p: entry.palette).frame(width: 90)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lull").font(.headline).foregroundStyle(.white)
                    Text(entry.palette.name).font(.caption).foregroundStyle(.white.opacity(0.6))
                    Link(destination: URL(string: "lull://session/sos")!) {
                        Label("Quick calm", systemImage: "wind").font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(hex: entry.palette.hot).opacity(0.35), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Link(destination: URL(string: "lull://session/sleep")!) {
                        Label("Drift to sleep", systemImage: "moon.zzz").font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            MiniLamp(p: entry.palette)
        }
    }
}

// MARK: - Lock Screen "Quick calm"

struct QuickCalmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LullQuickCalm", provider: PaletteProvider()) { entry in
            QuickCalmView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "lull://session/sos"))
        }
        .configurationDisplayName("Quick calm")
        .description("One tap to a two-minute breathing session.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct QuickCalmView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PaletteEntry
    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "drop.fill").font(.title3)
            }
        } else {
            HStack {
                Image(systemName: "drop.fill")
                VStack(alignment: .leading) {
                    Text("Quick calm").font(.headline)
                    Text("2 min · breathe with the lamp").font(.caption)
                }
            }
        }
    }
}

// MARK: - Live Activity (Lock Screen + Dynamic Island)

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { ctx in
            HStack(spacing: 14) {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: ctx.state.hot), Color(hex: ctx.state.cool)], center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: 22))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(hex: ctx.state.hot).opacity(0.7), radius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ctx.attributes.sessionName).font(.headline)
                    Text("Breathe with the lamp").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: Date.now...max(ctx.state.endDate, Date.now), countsDown: true)
                    .font(.title3.monospacedDigit()).frame(width: 64)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Circle().fill(Color(hex: ctx.state.hot)).frame(width: 28, height: 28)
                }
                DynamicIslandExpandedRegion(.center) { Text(ctx.attributes.sessionName).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(ctx.state.endDate, Date.now), countsDown: true)
                        .monospacedDigit().frame(width: 56)
                }
            } compactLeading: {
                Circle().fill(Color(hex: ctx.state.hot)).frame(width: 14, height: 14)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(ctx.state.endDate, Date.now), countsDown: true)
                    .monospacedDigit().frame(width: 40)
            } minimal: {
                Circle().fill(Color(hex: ctx.state.hot)).frame(width: 12, height: 12)
            }
        }
    }
}
