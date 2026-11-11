import SwiftUI

struct UpperPushView: View {
    @Environment(SessionStore.self) private var store
    @State private var didSave = false

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
                        .padding(.top, 64)

                    glanceCard
                        .padding(.top, 64)

                    Text(routine.summary)
                        .font(.body)
                        .padding(.top, 24)

                    section("Warm-up", steps: routine.warmup)
                    exerciseSection
                    section("Cool Down", steps: routine.cooldown)

                    credit
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .background { ThermalWashBackground() }
            .navigationTitle("Routine A")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Complete Workout") {
                        store.complete(routine)
                        didSave = true
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbarBackgroundVisibility(.visible, for: .bottomBar)
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(routine.exercises.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("exercises")
                    .font(.subheadline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("60")
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("minutes")
                    .font(.subheadline)
            }
            Spacer()
            VStack(spacing: 3) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.white.opacity(index < 3 ? 1 : 0.35))
                            .frame(width: 8, height: 31)
                    }
                }
                .accessibilityHidden(true)
                Text("Difficulty")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 100)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("5 exercises, 60 minutes, difficulty three of five")
    }

    private func section(_ title: String, steps: [GuideStep]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 6) {
                    ForEach(steps) { step in
                        GuideRow(title: step.title, meta: step.meta, slug: step.slug)
                    }
                }
            }
        }
        .padding(.top, 48)
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Exercise")
                .font(.title2)
                .fontWeight(.bold)
            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 6) {
                    ForEach(routine.exercises) { exercise in
                        GuideRow(title: exercise.name, meta: exercise.meta, slug: exercise.slug)
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
    let meta: String
    let slug: String

    var body: some View {
        HStack(spacing: 20) {
            IllustrationView(slug: slug, label: title)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 152)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

#Preview {
    UpperPushView()
        .environment(SessionStore())
}
