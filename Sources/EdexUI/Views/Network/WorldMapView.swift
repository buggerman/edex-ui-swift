import SwiftUI

// Canvas-based equirectangular world map with continent outlines and user location dot

struct WorldMapView: View {
    let userLat: Double?
    let userLon: Double?
    let theme: EdexTheme

    @State private var pulse: Double = 0

    // Continent polygons as (lat, lon) pairs
    private let northAmerica: [(Double, Double)] = [
        (72,-141),(70,-143),(67,-163),(64,-168),(60,-147),(58,-137),(56,-133),
        (52,-128),(48,-124),(40,-124),(32,-117),(22,-106),(15,-87),(10,-83),
        (10,-75),(18,-67),(24,-82),(32,-80),(36,-76),(44,-66),(48,-53),(52,-56),
        (58,-62),(60,-65),(64,-82),(64,-88),(62,-91),(67,-80),(68,-68),(72,-62),
        (76,-78),(76,-96),(73,-120),(73,-130),(72,-141)
    ]

    private let southAmerica: [(Double, Double)] = [
        (10,-75),(8,-77),(6,-61),(4,-52),(1,-50),(-5,-36),(-10,-38),(-23,-43),
        (-34,-52),(-38,-57),(-42,-63),(-55,-68),(-56,-67),(-54,-65),(-40,-73),
        (-30,-71),(-18,-70),(-5,-81),(0,-80),(8,-76),(10,-75)
    ]

    private let europe: [(Double, Double)] = [
        (72,-7),(60,-1),(58,-6),(50,-5),(44,-9),(36,-6),(36,3),(43,5),(46,13),
        (40,18),(37,15),(38,20),(42,28),(38,34),(36,36),(40,35),(44,35),(44,33),
        (47,30),(56,38),(60,28),(64,26),(70,26),(72,28),(70,33),(66,33),(66,40),
        (70,46),(72,56),(68,52),(64,40),(60,30),(57,24),(60,22),(60,26),(72,-7)
    ]

    private let africa: [(Double, Double)] = [
        (37,-6),(37,12),(30,33),(22,38),(12,44),(10,50),(0,42),(-5,40),
        (-12,40),(-20,35),(-35,18),(-30,17),(-25,15),(-5,8),(5,-2),
        (5,-10),(10,-16),(15,-17),(22,-17),(28,-15),(35,-5),(37,-6)
    ]

    private let asia: [(Double, Double)] = [
        (72,56),(68,52),(64,40),(56,38),(47,30),(42,28),(38,34),(40,35),
        (36,36),(36,50),(30,48),(22,60),(15,51),(10,44),(10,56),(12,44),
        (0,42),(5,46),(1,104),(5,100),(10,106),(20,110),(25,120),(30,121),
        (35,127),(40,129),(44,133),(50,142),(55,132),(55,142),(58,141),
        (64,140),(68,143),(72,130),(72,104),(78,102),(78,60),(72,56)
    ]

    private let australia: [(Double, Double)] = [
        (-10,142),(-15,145),(-20,149),(-30,153),(-38,145),(-40,144),
        (-38,140),(-35,137),(-32,124),(-22,114),(-14,126),(-10,136),(-10,142)
    ]

    private let antarctica: [(Double, Double)] = [
        (-68,180),(-68,150),(-68,100),(-68,50),(-68,0),(-68,-50),
        (-68,-100),(-68,-150),(-68,-180),(-90,-180),(-90,180),(-68,180)
    ]

    var body: some View {
        Canvas { ctx, size in
            drawGraticule(ctx: ctx, size: size)
            let continents = [northAmerica, southAmerica, europe, africa, asia, australia, antarctica]
            for continent in continents {
                drawContinent(ctx: ctx, size: size, points: continent)
            }
            if let lat = userLat, let lon = userLon {
                drawUserDot(ctx: ctx, size: size, lat: lat, lon: lon)
            }
        }
        .background(theme.bgSecondary.opacity(0.5))
        .cornerRadius(2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = 1.0
            }
        }
    }

    // MARK: - Projection

    private func project(lat: Double, lon: Double, in size: CGSize) -> CGPoint {
        let x = (lon + 180.0) / 360.0 * size.width
        let y = (90.0 - lat) / 180.0 * size.height
        return CGPoint(x: x, y: y)
    }

    // MARK: - Drawing helpers

    private func drawGraticule(ctx: GraphicsContext, size: CGSize) {
        var grid = Path()
        // Horizontal lines every 30°
        for lat in stride(from: -90.0, through: 90.0, by: 30.0) {
            let start = project(lat: lat, lon: -180, in: size)
            let end   = project(lat: lat, lon:  180, in: size)
            grid.move(to: start)
            grid.addLine(to: end)
        }
        // Vertical lines every 30°
        for lon in stride(from: -180.0, through: 180.0, by: 30.0) {
            let start = project(lat:  90, lon: lon, in: size)
            let end   = project(lat: -90, lon: lon, in: size)
            grid.move(to: start)
            grid.addLine(to: end)
        }
        ctx.stroke(grid, with: .color(theme.textColor.opacity(0.08)), lineWidth: 0.5)
    }

    private func drawContinent(ctx: GraphicsContext, size: CGSize, points: [(Double, Double)]) {
        guard points.count > 1 else { return }
        var path = Path()
        let first = project(lat: points[0].0, lon: points[0].1, in: size)
        path.move(to: first)
        for pt in points.dropFirst() {
            path.addLine(to: project(lat: pt.0, lon: pt.1, in: size))
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(theme.textColor.opacity(0.15)))
        ctx.stroke(path, with: .color(theme.textColor.opacity(0.35)), lineWidth: 0.5)
    }

    private func drawUserDot(ctx: GraphicsContext, size: CGSize, lat: Double, lon: Double) {
        let pt = project(lat: lat, lon: lon, in: size)
        let baseR: Double = 3.0

        // Expanding rings driven by pulse
        for i in 1...2 {
            let scale = Double(i) * pulse * 3.5
            let ringR = baseR + scale
            let ringRect = CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2)
            let ringPath = Path(ellipseIn: ringRect)
            let opacity = (1.0 - pulse * 0.6) / Double(i)
            ctx.stroke(ringPath, with: .color(theme.borderColor.opacity(opacity)), lineWidth: 0.8)
        }

        // Solid center dot
        let dotRect = CGRect(x: pt.x - baseR, y: pt.y - baseR, width: baseR * 2, height: baseR * 2)
        let dotPath = Path(ellipseIn: dotRect)
        ctx.fill(dotPath, with: .color(theme.borderColor))
    }
}
