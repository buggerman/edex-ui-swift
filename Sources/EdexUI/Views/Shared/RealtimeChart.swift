import SwiftUI

// Real-time scrolling line chart — native replacement for SmoothieChart.
// Keeps a circular buffer of the last N samples and draws them with Canvas.
// Mirrors the canvas-based charts in src/components/system/hardwareInfo/load.tsx

struct RealtimeChart: View {
    /// Current data point(s) to append. One entry per "series" (e.g. per core).
    let values: [Double]    // 0–100
    let color: Color
    var maxValue: Double = 100
    var bufferSize: Int  = 60   // seconds of history

    @State private var history: [[Double]] = []

    var body: some View {
        Canvas { ctx, size in
            guard !history.isEmpty else { return }
            let w = size.width
            let h = size.height
            let step = w / CGFloat(max(bufferSize - 1, 1))

            // Draw dashed top/bottom guide lines (mirrors border-dashed in original CSS)
            var dash = Path()
            dash.move(to: .init(x: 0, y: 0)); dash.addLine(to: .init(x: w, y: 0))
            dash.move(to: .init(x: 0, y: h)); dash.addLine(to: .init(x: w, y: h))
            ctx.stroke(dash, with: .color(color.opacity(0.2)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

            // One path per series (e.g. one per CPU core)
            let seriesCount = history.first?.count ?? 1
            for s in 0..<seriesCount {
                var path = Path()
                for (i, frame) in history.enumerated() {
                    let val = frame.count > s ? frame[s] : 0
                    let x = CGFloat(i) * step
                    let y = h - (CGFloat(val) / CGFloat(maxValue)) * h
                    if i == 0 { path.move(to: .init(x: x, y: y)) }
                    else       { path.addLine(to: .init(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(color.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            }
        }
        .onChange(of: values) { _, newValues in
            history.append(newValues)
            if history.count > bufferSize { history.removeFirst() }
        }
    }
}

// MARK: - Dual-axis chart for network traffic (upload positive / download negative)
// Mirrors src/components/network/traffic/index.tsx

struct NetworkChart: View {
    let uploadRate:   Double   // bytes/sec
    let downloadRate: Double   // bytes/sec
    let color: Color
    var bufferSize: Int = 60

    @State private var uploadHistory:   [Double] = []
    @State private var downloadHistory: [Double] = []
    @State private var maxRate: Double = 1

    var body: some View {
        Canvas { ctx, size in
            guard !uploadHistory.isEmpty else { return }
            let w = size.width
            let h = size.height
            let mid = h / 2
            let step = w / CGFloat(max(bufferSize - 1, 1))
            let scale = maxRate > 0 ? mid / CGFloat(maxRate) : 1

            // Centre axis
            var axis = Path()
            axis.move(to: .init(x: 0, y: mid)); axis.addLine(to: .init(x: w, y: mid))
            ctx.stroke(axis, with: .color(color.opacity(0.2)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

            // Upload (above centre)
            var up = Path()
            for (i, val) in uploadHistory.enumerated() {
                let x = CGFloat(i) * step
                let y = mid - CGFloat(val) * scale
                if i == 0 { up.move(to: .init(x: x, y: y)) }
                else       { up.addLine(to: .init(x: x, y: y)) }
            }
            ctx.stroke(up, with: .color(color.opacity(0.8)),
                       style: StrokeStyle(lineWidth: 1, lineCap: .round))

            // Download (below centre)
            var down = Path()
            for (i, val) in downloadHistory.enumerated() {
                let x = CGFloat(i) * step
                let y = mid + CGFloat(val) * scale
                if i == 0 { down.move(to: .init(x: x, y: y)) }
                else       { down.addLine(to: .init(x: x, y: y)) }
            }
            ctx.stroke(down, with: .color(color.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        .onChange(of: uploadRate) { _, v in
            uploadHistory.append(v)
            if uploadHistory.count > bufferSize { uploadHistory.removeFirst() }
            maxRate = max(
                (uploadHistory  + downloadHistory).max() ?? 1,
                1
            )
        }
        .onChange(of: downloadRate) { _, v in
            downloadHistory.append(v)
            if downloadHistory.count > bufferSize { downloadHistory.removeFirst() }
        }
    }
}
