import SwiftUI

/// The large geometric shape behind each stat card (DESIGN.md, "Stat card").
public enum CardShape: Sendable {
    case circle, triangle, star, heart, hexagon, square, chevron, ring, cog

    /// Size, offset from the anchor corner, rotation and anchor of the shape inside its card.
    public var placement: (size: CGSize, offset: CGSize, degrees: Double, anchor: Alignment) {
        switch self {
        case .circle: (CGSize(width: 176, height: 176), CGSize(width: 48, height: -58), 0, .topTrailing)
        case .triangle: (CGSize(width: 150, height: 150), CGSize(width: 34, height: -26), 14, .topTrailing)
        case .star: (CGSize(width: 158, height: 158), CGSize(width: 30, height: 56), 0, .bottomTrailing)
        case .heart: (CGSize(width: 142, height: 130), CGSize(width: 30, height: -22), 0, .topTrailing)
        case .hexagon: (CGSize(width: 156, height: 156), CGSize(width: 40, height: -44), 0, .topTrailing)
        case .square: (CGSize(width: 130, height: 130), CGSize(width: 30, height: -36), 15, .topTrailing)
        case .chevron: (CGSize(width: 150, height: 150), CGSize(width: 36, height: -30), 0, .topTrailing)
        case .ring: (CGSize(width: 160, height: 160), CGSize(width: 44, height: -50), 0, .topTrailing)
        case .cog: (CGSize(width: 170, height: 170), CGSize(width: 46, height: -52), 0, .topTrailing)
        }
    }

    public func path(in rect: CGRect) -> Path {
        switch self {
        case .circle: Path(ellipseIn: rect)
        case .triangle: polygon(in: rect, points: [(0.5, 0.04), (0.98, 0.96), (0.02, 0.96)])
        case .star: radial(in: rect, points: 8, inner: 0.42, rotation: -.pi / 2)
        case .heart: heart(in: rect)
        case .hexagon: radial(in: rect, points: 3, inner: 1, rotation: 0)
        case .square: Path(rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        case .chevron: polygon(in: rect, points: [(0.1, 0.1), (0.55, 0.1), (0.95, 0.5), (0.55, 0.9), (0.1, 0.9), (0.5, 0.5)])
        case .ring: ring(in: rect)
        case .cog: cog(in: rect)
        }
    }

    private func polygon(in rect: CGRect, points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height) })
        path.closeSubpath()
        return path
    }

    /// A star or regular polygon: `points` outer vertices alternating with inner ones at `inner` of the radius.
    private func radial(in rect: CGRect, points: Int, inner: CGFloat, rotation: CGFloat) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let vertices = (0..<points * 2).map { i -> CGPoint in
            let angle = rotation + CGFloat(i) * .pi / CGFloat(points)
            let r = i.isMultiple(of: 2) ? radius : radius * inner
            return CGPoint(x: centre.x + cos(angle) * r, y: centre.y + sin(angle) * r)
        }
        var path = Path()
        path.addLines(vertices)
        path.closeSubpath()
        return path
    }

    private func heart(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 92 * rect.height)
        }
        var path = Path()
        path.move(to: p(50, 88))
        path.addCurve(to: p(2, 30), control1: p(20, 66), control2: p(2, 48))
        path.addCurve(to: p(28, 4), control1: p(2, 14), control2: p(14, 4))
        path.addCurve(to: p(50, 18), control1: p(38, 4), control2: p(46, 10))
        path.addCurve(to: p(72, 4), control1: p(54, 10), control2: p(62, 4))
        path.addCurve(to: p(98, 30), control1: p(86, 4), control2: p(98, 14))
        path.addCurve(to: p(50, 88), control1: p(98, 48), control2: p(80, 66))
        path.closeSubpath()
        return path
    }

    private func ring(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: rect)
        path.addEllipse(in: rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.24))
        return path
    }

    /// A twelve-tooth cog with a round hole.
    private func cog(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let root = outer * 0.8
        let teeth = 12
        let step = 2 * CGFloat.pi / CGFloat(teeth)
        var path = Path()
        for tooth in 0..<teeth {
            let start = CGFloat(tooth) * step
            // Each tooth: rise, flat top, fall, then the valley to the next tooth.
            let corners: [(CGFloat, CGFloat)] = [(0.08, root), (0.2, outer), (0.42, outer), (0.54, root)]
            for (index, corner) in corners.enumerated() {
                let angle = start + corner.0 * step
                let point = CGPoint(x: centre.x + cos(angle) * corner.1, y: centre.y + sin(angle) * corner.1)
                if tooth == 0 && index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: centre.x - outer * 0.3, y: centre.y - outer * 0.3, width: outer * 0.6, height: outer * 0.6))
        return path
    }
}

/// A `CardShape` as a SwiftUI `Shape`. Rings and cogs use even-odd fill so their holes stay open.
public struct CardShapeView: View {
    let shape: CardShape
    let color: Color

    public init(shape: CardShape, color: Color) {
        self.shape = shape
        self.color = color
    }

    private struct Outline: Shape {
        let shape: CardShape
        func path(in rect: CGRect) -> Path { shape.path(in: rect) }
    }

    public var body: some View {
        Outline(shape: shape)
            .fill(color, style: FillStyle(eoFill: true))
            .accessibilityHidden(true)
    }
}
