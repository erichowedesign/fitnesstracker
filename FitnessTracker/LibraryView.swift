import SwiftUI

struct LibraryView: View {
    @Binding var hidesFloatingTabBar: Bool
    @State private var path: [LibraryWorkout] = []
    @State private var query = ""
    @State private var equipment: String?
    @State private var chromeHidden = false
    @State private var lastScrollY: CGFloat = 0
    /// Accumulated downward travel while chrome is visible; reset on scroll up.
    @State private var downTravel: CGFloat = 0

    /// Stay visible through small/jittery downward moves; hide only after real intent.
    private let hideAfterDownTravel: CGFloat = 88
    /// Don’t start hiding until the list has moved past the chrome band.
    private let hideOnlyAfterOffset: CGFloat = 56
    /// Any clear upward tick brings chrome back immediately.
    private let showOnUpDelta: CGFloat = 1

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

    /// Match Home: last tiles can scroll clear of the pinned tab bar.
    private var libraryScrollBottomInset: CGFloat {
        max(WashPlayback.screenSize.height * 0.5, 400)
    }

    private var chromeHeight: CGFloat { 48 }
    private var chromeTopPadding: CGFloat { 8 }
    private var chromeBottomGap: CGFloat { 16 }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                Group {
                    if results.isEmpty {
                        Text("No workouts match that search.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, chromeTopPadding + chromeHeight + chromeBottomGap)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectHidden(true, for: .vertical)
            .contentMargins(.bottom, libraryScrollBottomInset, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newOffset in
                updateChrome(for: newOffset)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.clear, for: .navigation)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .background { LockRootPopGesture() }
            .navigationTitle("Library")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Library")
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .top) {
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
            .overlay(alignment: .top) {
                filterRow
                    .padding(.horizontal, 16)
                    .padding(.top, chromeTopPadding)
                    .offset(y: chromeHidden ? -(chromeTopPadding + chromeHeight + 12) : 0)
                    .opacity(chromeHidden ? 0 : 1)
                    .allowsHitTesting(!chromeHidden)
                    .animation(.smooth(duration: 0.28), value: chromeHidden)
            }
            .navigationDestination(for: LibraryWorkout.self) { workout in
                ExerciseTutorialView(
                    exerciseName: workout.name,
                    muscles: workout.muscle,
                    grade: workout.grade,
                    frames: workout.frames,
                    hints: workout.hints,
                    hintSource: workout.hintSource
                )
            }
        }
        .onChange(of: path) { _, newPath in
            hidesFloatingTabBar = !newPath.isEmpty
            if newPath.isEmpty {
                chromeHidden = false
            }
        }
    }

    private func updateChrome(for offset: CGFloat) {
        let delta = offset - lastScrollY
        lastScrollY = offset

        // Rubber-banding / top of list always reveals the controls.
        if offset <= 8 {
            downTravel = 0
            if chromeHidden {
                chromeHidden = false
            }
            return
        }

        // Scroll up: show immediately. Keep the same slide animation via chromeHidden.
        if delta <= -showOnUpDelta {
            downTravel = 0
            if chromeHidden {
                chromeHidden = false
            }
            return
        }

        guard delta > 0, !chromeHidden else { return }
        downTravel += delta
        if offset >= hideOnlyAfterOffset, downTravel >= hideAfterDownTravel {
            chromeHidden = true
            downTravel = 0
        }
    }

    private var filterRow: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Equipment", selection: $equipment) {
                    Text("All").tag(nil as String?)
                    ForEach(LibraryCatalog.equipment, id: \.self) { item in
                        Text(item).tag(item as String?)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .accessibilityLabel(equipment.map { "Filter by equipment, \($0)" } ?? "Filter by equipment")

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
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
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
