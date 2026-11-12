import SwiftUI

struct UpperPushView: View {
    @Environment(SessionStore.self) private var store
    @State private var didSave = false
    @State private var showCompleteButton = false

    private let routine = WorkoutPlan.upperPush()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(routine.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(routine.focus)
                        .font(.body)
                        .padding(.top, 8)

                    IllustrationView(slug: routine.heroSlug, label: routine.name)
                        .frame(maxWidth: .infinity)
                        .frame(height: 370)
                        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .padding(.top, 32)

                    glanceCard
                        .padding(.top, 16)

                    Text(routine.summary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)

                    section("Warm-up", steps: routine.warmup, revealsCompleteButton: true)
                    mainWorkoutSection
                    section("Cool Down", steps: routine.cooldown)

                    credit
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 88)
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .background { ThermalWashBackground() }
            .overlay(alignment: .top) {
                topStatusScrim
            }
            .overlay(alignment: .bottom) {
                ZStack {
                    if showCompleteButton {
                        completeWorkoutButton
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.4), value: showCompleteButton)
            }
            .navigationTitle("Routine A")
            .toolbarTitleDisplayMode(.inline)
            .alert("Workout saved", isPresented: $didSave) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Upper Push is stored on this iPhone.")
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    private var glanceCard: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 16)
            HStack(alignment: .top, spacing: 56) {
                VStack(alignment: .leading, spacing: 8) {
                    glanceLabel("exercises")
                    glanceNumber("05")
                }
                VStack(alignment: .leading, spacing: 8) {
                    glanceLabel("minutes")
                    glanceNumber("60")
                }
                VStack(spacing: 8) {
                    glanceLabel("difficulty")
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.white.opacity(index < 3 ? 1 : 0.35))
                                .frame(width: 8, height: 31)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 52)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("5 exercises, 60 minutes, difficulty three of five")
    }

    private func glanceLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .frame(height: 16, alignment: .leading)
    }

    private func glanceNumber(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 34, weight: .semibold))
            .monospacedDigit()
            .frame(height: 41, alignment: .leading)
    }

    private var topStatusScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0),
                .init(color: .black.opacity(0.12), location: 0.45),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 120)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var completeWorkoutButton: some View {
        Button {
            store.complete(routine)
            didSave = true
        } label: {
            Text("Complete Workout")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.extraLarge)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func section(_ title: String, steps: [GuideStep], revealsCompleteButton: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { _, frame in
                    guard revealsCompleteButton, frame.height > 1 else { return }
                    showCompleteButton = frame.minY <= UIScreen.main.bounds.height / 2
                }
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(steps) { step in
                        GuideRow(title: step.title, metaParts: step.metaParts, slug: step.slug)
                    }
                }
            }
        }
        .padding(.top, 48)
    }

    private var mainWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Main Workout")
                .font(.title2)
                .fontWeight(.bold)
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(routine.exercises) { exercise in
                        GuideRow(
                            title: exercise.name,
                            metaParts: exercise.metaParts,
                            slug: exercise.slug,
                            weight: exercise.displayWeight
                        )
                    }
                }
            }
        }
        .padding(.top, 48)
    }

    private var credit: some View {
        Text(.init("Drawings by Everkinetic, arranged by Bryl Lim. [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .tint(.white.opacity(0.8))
    }
}

private struct GuideRow: View {
    let title: String
    let metaParts: [String]
    let slug: String
    var weight: String? = nil

    var body: some View {
        HStack(spacing: 20) {
            IllustrationView(slug: slug, label: title)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                MetaLine(parts: metaParts)
                    .padding(.top, 4)
                if let weight {
                    Text("Weight")
                        .font(.headline)
                        .padding(.top, 20)
                    Text(weight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

private struct MetaLine: View {
    let parts: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text("·")
                }
                Text(part)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

#Preview {
    UpperPushView()
        .environment(SessionStore())
}
