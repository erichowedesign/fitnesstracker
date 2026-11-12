import SwiftUI

struct LibraryView: View {
    @Environment(WashTheme.self) private var wash
    @Binding var hidesFloatingTabBar: Bool
    @State private var path: [LibraryWorkout] = []
    @State private var query = ""
    @State private var equipment: String?

    init(hidesFloatingTabBar: Binding<Bool> = .constant(false)) {
        _hidesFloatingTabBar = hidesFloatingTabBar
    }

    private var results: [LibraryWorkout] {
        LibraryCatalog.workouts.filter { workout in
            if let equipment, workout.equipment != equipment {
                return false
            }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            return workout.name.localizedStandardContains(trimmed)
                || workout.muscle.localizedStandardContains(trimmed)
                || workout.equipment.localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                filterRow
                    .padding(.top, 8)

                ScrollView {
                    if results.isEmpty {
                        Text("No workouts match that search.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(results) { workout in
                                Button {
                                    path.append(workout)
                                } label: {
                                    LibraryTile(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 24)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Color.black
                    WashBackground(grade: wash.grade)
                }
                .ignoresSafeArea()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("Library")
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: LibraryWorkout.self) { workout in
                ExerciseTutorialView(
                    exerciseName: workout.name,
                    muscles: workout.muscle,
                    grade: workout.grade,
                    frames: workout.frames,
                    hints: workout.hints
                )
            }
        }
        .onChange(of: path) { _, newPath in
            hidesFloatingTabBar = !newPath.isEmpty
        }
    }

    private var filterRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .glassEffect(.regular.interactive(), in: Capsule())

            Menu {
                Picker("Equipment", selection: $equipment) {
                    Text("All").tag(nil as String?)
                    ForEach(LibraryCatalog.equipment, id: \.self) { item in
                        Text(item).tag(item as String?)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 15, weight: .semibold))
                    Text(equipment ?? "All")
                        .font(.subheadline)
                        .lineLimit(1)
                        .frame(maxWidth: 96)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            .accessibilityLabel("Filter by equipment")
        }
    }
}

private struct LibraryTile: View {
    let workout: LibraryWorkout

    var body: some View {
        HStack(spacing: 20) {
            IllustrationView(slug: workout.frames[0], label: workout.name)
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)
            Text(workout.name)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workout.name)
        .accessibilityHint("Opens the tutorial")
    }
}

#Preview {
    LibraryView()
        .environment(WashTheme())
        .preferredColorScheme(.dark)
}
