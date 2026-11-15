import SwiftUI
import DeskKit

/// 03: coursework. The scenes run down the window; here the story turns sideways. Three projects stand on a
/// carousel in depth: one faces the reader, the others wait behind it on either side. Opening a project
/// brings its bench forward and pushes the carousel back.
struct IcaiChapter: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t
    @Environment(\.sceneActive) private var active
    @Environment(\.motionOn) private var motionOn
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let icai: Story.Icai

    var body: some View {
        let animated = motionOn && !reduceMotion
        let open = reader.projectOpen && icai.projects.indices.contains(reader.project)
        let spring = animated ? Animation.spring(response: t.carouselSpring, dampingFraction: t.liftDamping) : nil
        VStack(alignment: .leading, spacing: t.sp12) {
            ChapterHeader(chapter: .icai, headline: icai.headline, note: icai.note).reveal(0)
            ZStack {
                carousel(spread: active || !animated ? 1 : 0)
                    .scaleEffect(open ? t.carouselBack : 1)
                    .opacity(open ? t.carouselBackOpacity : 1)
                    .blur(radius: open ? t.sp6 : 0)
                    .allowsHitTesting(!open)
                    .accessibilityHidden(open)
                if open {
                    ProjectBench(project: icai.projects[reader.project], close: icai.closeLabel) { reader.projectOpen = false }
                        .transition(.scale(scale: t.carouselBack).combined(with: .opacity))
                        .id(reader.project)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: t.carouselHeight)
            .animation(spring, value: open)
            .animation(spring, value: reader.project)
            .animation(animated ? .spring(response: t.carouselSpring + t.carouselSpring, dampingFraction: t.liftDamping) : nil, value: active)
            footer.reveal(1)
        }
    }

    /// The cards in depth. `spread` 0 is the stack the reader finds on the way in; 1 is the carousel, swung out sideways.
    private func carousel(spread: CGFloat) -> some View {
        ZStack {
            ForEach(Array(icai.projects.enumerated()), id: \.offset) { index, project in
                let away = CGFloat(index - reader.project)
                let facing = index == reader.project
                ProjectCard(project: project, facing: facing, open: icai.openLabel) {
                    if facing { reader.projectOpen = true } else { reader.project = index }
                }
                .frame(width: t.projectCard.width, height: t.projectCard.height)
                .shadow(color: .black.opacity(facing ? t.depthShadowOpacity : 0), radius: t.depthShadow, y: t.depthShadowY)
                .scaleEffect(1 - min(abs(away), 2) * (1 - t.carouselSideScale) * spread)
                .rotation3DEffect(.degrees(-Double(away) * t.carouselTurn * spread), axis: (x: 0, y: 1, z: 0), perspective: t.carouselPerspective)
                .rotation3DEffect(.degrees(Double(1 - spread) * t.carouselTilt), axis: (x: 1, y: 0, z: 0), perspective: t.carouselPerspective)
                .offset(x: away * t.carouselStep * spread, y: (1 - spread) * away * t.carouselStack)
                .opacity(facing ? 1 : t.carouselSideOpacity)
                .zIndex(-Double(abs(away)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: t.sp12) {
            HStack(spacing: t.sp6) {
                ForEach(icai.projects.indices, id: \.self) { index in
                    Button {
                        reader.project = index
                    } label: {
                        Capsule().fill(index == reader.project ? t.focus : t.line)
                            .frame(width: index == reader.project ? t.dotWide : t.dot, height: t.dot)
                            .padding(.vertical, t.sp8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: icai.projects[index].title))
                }
            }
            Text(verbatim: icai.hint).style(\.small, \.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .deskAnimation(reader.project)
    }
}

/// One project on the carousel: where it comes from, what it was, a small moving preview of its bench.
private struct ProjectCard: View {
    @Environment(\.theme) private var t
    let project: Story.Icai.Project
    let facing: Bool
    let open: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp10) {
            Text(verbatim: project.course).style(\.label, \.focus).lineLimit(1).minimumScaleFactor(t.tightScale)
            Text(verbatim: project.title).style(\.section, \.ink).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: project.summary).style(\.body, \.inkMuted).lineSpacing(t.sp2).fixedSize(horizontal: false, vertical: true)
            Bench(project: project, moving: facing)
                .frame(height: t.previewHeight)
                .frame(maxHeight: .infinity)
            HStack(spacing: t.sp6) {
                ForEach(project.tools, id: \.self) { Chip(text: $0) }
                Spacer(minLength: 0)
                if facing {
                    Button(open, action: action).buttonStyle(.deskPrimary)
                }
            }
            .frame(height: t.sp32)
        }
        .padding(t.sp20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glass(fill: facing ? t.raised : t.surface, lifts: facing)
        .contentShape(RoundedRectangle(cornerRadius: t.radiusCard))
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A project opened: the facts on the left, its bench to play with on the right.
private struct ProjectBench: View {
    @Environment(\.theme) private var t
    let project: Story.Icai.Project
    let close: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: t.sp24) {
            VStack(alignment: .leading, spacing: t.sp12) {
                Text(verbatim: project.course).style(\.label, \.focus).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: project.title).style(\.title, \.ink).fixedSize(horizontal: false, vertical: true)
                ForEach(project.facts, id: \.self) { fact in
                    VStack(alignment: .leading, spacing: t.sp2) {
                        Text(verbatim: fact.title).style(\.bodyStrong, \.ink)
                        Text(verbatim: fact.detail).style(\.small, \.inkMuted).lineSpacing(t.sp2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    if let figure = project.figure {
                        Figure(figure.value, unit: figure.spacedUnit, caption: figure.caption).foregroundStyle(t.ink)
                    }
                    Spacer(minLength: t.sp8)
                    Button(close, action: dismiss).buttonStyle(.deskSecondary)
                }
            }
            .frame(width: t.deepWords, alignment: .leading)
            Bench(project: project, live: true)
                .padding(t.sp16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .glass(radius: t.radiusRow, fill: t.surface, lifts: false)
        }
        .padding(t.sp24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glass(fill: t.floating, lifts: false)
        .shadow(color: .black.opacity(t.depthShadowOpacity), radius: t.depthShadow, y: t.depthShadowY)
    }
}
