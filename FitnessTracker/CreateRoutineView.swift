import SwiftUI

/// Title + section chooser — same glass / dose-row language as tutorial adjusters.
struct CreateRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassPalette) private var palette
    @Environment(CustomRoutinesStore.self) private var customRoutines

    var onCreated: (Routine) -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var includeWarmup = true
    @State private var includeMain = true
    @State private var includeCooldown = true

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDetail: String {
        detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedTitle.isEmpty && (includeWarmup || includeMain || includeCooldown)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Create routine")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .glassInk()
                Text("Name it, pick the sections you want, then add workouts.")
                    .font(.body)
                    .glassInk()
                    .padding(.top, 8)

                Text("Title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .glassInk()
                    .padding(.top, 48)

                TextField("Routine name", text: $title)
                    .font(.headline)
                    .glassInk()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .foundationGlass(interactive: true, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .padding(.top, 24)
                    .submitLabel(.next)

                Text("Description")
                    .font(.title2)
                    .fontWeight(.bold)
                    .glassInk()
                    .padding(.top, 48)

                TextField("Optional — shown under the title", text: $detail, axis: .vertical)
                    .font(.body)
                    .glassInk()
                    .lineLimit(3...6)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .foundationGlass(interactive: true, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .padding(.top, 24)
                    .submitLabel(.done)

                Text("Sections")
                    .font(.title2)
                    .fontWeight(.bold)
                    .glassInk()
                    .padding(.top, 48)

                VStack(spacing: 12) {
                    sectionToggle(label: "Warm-up", isOn: $includeWarmup)
                    sectionToggle(label: "Main workout", isOn: $includeMain)
                    sectionToggle(label: "Cool Down", isOn: $includeCooldown)
                }
                .padding(.top, 24)

                Button(action: createAndContinue) {
                    Text("Continue")
                        .font(.title3.weight(.semibold))
                        .glassInk()
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                }
                .buttonStyle(.plain)
                .foundationGlass(interactive: true, in: Capsule())
                .opacity(canContinue ? 1 : 0.45)
                .allowsHitTesting(canContinue)
                .padding(.top, 48)
                .padding(.bottom, 32)
                .accessibilityLabel("Continue")
            }
            .padding(.horizontal, 16)
            .padding(.top, 34)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .glassInk()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Create")
        .toolbarTitleDisplayMode(.inline)
        .preferredColorScheme(palette.colorScheme)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                GlassChromeIconButton(
                    systemName: "xmark",
                    accessibilityLabel: "Close",
                    action: { dismiss() }
                )
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private func sectionToggle(label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.headline)
                .glassInk()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            Spacer(minLength: 0)
            Toggle(label, isOn: isOn)
                .labelsHidden()
                .tint(palette.accent)
                .padding(.horizontal, 12)
                .frame(height: 52)
                .foundationGlass(interactive: true, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func createAndContinue() {
        guard canContinue else { return }
        let routine = customRoutines.create(
            name: trimmedTitle,
            detail: trimmedDetail,
            includesWarmup: includeWarmup,
            includesMain: includeMain,
            includesCooldown: includeCooldown
        )
        onCreated(routine)
    }
}
