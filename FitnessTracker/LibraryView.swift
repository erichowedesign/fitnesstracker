import SwiftUI

enum LibraryListFilter: Hashable {
    case all
    case equipment(String)
}

struct LibraryView: View {
    @Binding var hidesFloatingTabBar: Bool
    @State private var path: [LibraryWorkout] = []
    @State private var query = ""
    @State private var filter: LibraryListFilter = .all
    @State private var favoritesOnly = false

    init(hidesFloatingTabBar: Binding<Bool> = .constant(false)) {
        _hidesFloatingTabBar = hidesFloatingTabBar
    }

    var body: some View {
        NavigationStack(path: $path) {
            LibraryBrowser(
                query: $query,
                filter: $filter,
                favoritesOnly: $favoritesOnly,
                showsIllustrationCredit: true,
                bottomInset: max(WashPlayback.screenSize.height * 0.5, 400)
            ) { workout in
                path.append(workout)
            }
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
            .navigationDestination(for: LibraryWorkout.self) { workout in
                ExerciseTutorialView(
                    exerciseName: workout.name,
                    muscles: workout.muscle,
                    grade: workout.grade,
                    frames: workout.frames,
                    hints: workout.hints,
                    hintSource: workout.hintSource,
                    favoriteSlug: workout.slug,
                    sectionTitle: "Tutorial"
                )
            }
        }
        .onChange(of: path) { _, newPath in
            hidesFloatingTabBar = !newPath.isEmpty
        }
    }
}

/// Shared Library chrome: filter + search (top) + large glass tiles.
struct LibraryBrowser: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.glassPalette) private var palette

    @Binding var query: String
    @Binding var filter: LibraryListFilter
    @Binding var favoritesOnly: Bool

    var title: String = "Library"
    var showsCancel: Bool = false
    var showsIllustrationCredit: Bool = false
    var bottomInset: CGFloat = 24
    var onCancel: (() -> Void)? = nil
    var onSelect: (LibraryWorkout) -> Void

    private var chromeHeight: CGFloat { 48 }
    private var chromeTopPadding: CGFloat { 8 }
    private var chromeBottomGap: CGFloat { 16 }

    private var results: [LibraryWorkout] {
        LibraryCatalog.workouts.filter { workout in
            if favoritesOnly {
                guard favorites.isLiked(workout.slug) else { return false }
            }
            switch filter {
            case .all:
                break
            case .equipment(let equipment):
                guard workout.equipment == equipment else { return false }
            }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            return workout.name.localizedStandardContains(trimmed)
                || workout.muscle.localizedStandardContains(trimmed)
                || workout.equipment.localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            Group {
                if results.isEmpty {
                    Text(emptyMessage)
                        .font(.body)
                        .glassInk(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { workout in
                            LibraryTile(workout: workout) {
                                onSelect(workout)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, chromeTopPadding + chromeHeight + chromeBottomGap)
            .padding(.bottom, showsIllustrationCredit ? 8 : 24)

            if showsIllustrationCredit {
                illustrationCredit
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectHidden(true, for: .vertical)
        .contentMargins(.bottom, bottomInset, for: .scrollContent)
        .glassInk()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .navigation)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .preferredColorScheme(palette.colorScheme)
        .animation(.smooth(duration: 0.3), value: palette.mode)
        .overlay(alignment: .top) {
            LibraryTopScrim()
        }
        .overlay(alignment: .top) {
            LibraryFilterSearchChrome(
                query: $query,
                filter: $filter,
                favoritesOnly: $favoritesOnly
            )
            .padding(.horizontal, 16)
            .padding(.top, chromeTopPadding)
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassChromeLabelButton(title: "Cancel") {
                        onCancel?()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    private var emptyMessage: String {
        if favoritesOnly {
            return "No favorite workouts yet. Tap the heart on a tile to save one."
        }
        return "No workouts match that search."
    }

    private var illustrationCredit: some View {
        Text(.init("Drawings by Everkinetic, arranged by Bryl Lim. [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)"))
            .font(.caption)
            .glassInk(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .tint(palette.chrome.opacity(0.85))
    }
}

private struct LibraryTopScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(
                    color: Color.black.opacity(0.28),
                    location: 0
                ),
                .init(
                    color: Color.black.opacity(0.12),
                    location: 0.45
                ),
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
}

/// Resting: filter | search | heart. Focused: search full-width | X (heart transforms; filter hides).
struct LibraryFilterSearchChrome: View {
    @Environment(\.glassPalette) private var palette
    @Binding var query: String
    @Binding var filter: LibraryListFilter
    @Binding var favoritesOnly: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if !searchFocused {
                filterMenu
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            searchField
            if searchFocused {
                clearButton
                    .transition(.scale.combined(with: .opacity))
            } else {
                favoritesButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: searchFocused)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                Text("All").tag(LibraryListFilter.all)
                ForEach(LibraryCatalog.equipment, id: \.self) { item in
                    Text(item).tag(LibraryListFilter.equipment(item))
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.chrome)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .foundationGlass(interactive: true, in: Circle())
        .accessibilityLabel(filterAccessibilityLabel)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .glassInk(.secondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .glassInk()
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .foundationGlass(interactive: true, in: Capsule())
    }

    private var favoritesButton: some View {
        GlassChromeIconButton(
            systemName: favoritesOnly ? "heart.fill" : "heart",
            accessibilityLabel: favoritesOnly ? "Showing favorites" : "Show favorites",
            ink: favoritesOnly ? palette.heart : nil,
            action: { favoritesOnly.toggle() }
        )
        .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
    }

    private var clearButton: some View {
        GlassChromeIconButton(
            systemName: "xmark",
            accessibilityLabel: "Clear search",
            action: {
                query = ""
                searchFocused = false
            }
        )
    }

    private var filterAccessibilityLabel: String {
        switch filter {
        case .all:
            return "Filter, All"
        case .equipment(let item):
            return "Filter by equipment, \(item)"
        }
    }
}

struct LibraryTile: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.glassPalette) private var palette
    let workout: LibraryWorkout
    var onOpen: () -> Void

    private var isLiked: Bool { favorites.isLiked(workout.slug) }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onOpen) {
                HStack(spacing: 20) {
                    IllustrationView(slug: workout.frames[0], label: workout.name)
                        .frame(width: 120, height: 120)
                        .accessibilityHidden(true)
                    Text(workout.name)
                        .font(.headline)
                        .glassInk()
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(workout.name)
            .accessibilityHint("Opens the tutorial")

            Button {
                favorites.toggle(workout.slug)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isLiked ? palette.heart : palette.chrome)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Remove from favorites" : "Add to favorites")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

#Preview {
    LibraryView()
        .environment(FavoritesStore())
        .environment(WashTheme())
        .preferredColorScheme(.dark)
}
