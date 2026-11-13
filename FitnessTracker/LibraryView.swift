import SwiftUI

enum LibraryListFilter: Hashable {
    case all
    case favorites
    case equipment(String)
}

struct LibraryView: View {
    @Binding var hidesFloatingTabBar: Bool
    @Binding var query: String
    @Binding var filter: LibraryListFilter
    @State private var path: [LibraryWorkout] = []

    init(
        hidesFloatingTabBar: Binding<Bool> = .constant(false),
        query: Binding<String> = .constant(""),
        filter: Binding<LibraryListFilter> = .constant(.all)
    ) {
        _hidesFloatingTabBar = hidesFloatingTabBar
        _query = query
        _filter = filter
    }

    var body: some View {
        NavigationStack(path: $path) {
            LibraryBrowser(
                query: $query,
                filter: $filter,
                showsTopChrome: false,
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

/// Shared Library chrome: search/filter + large glass tiles.
struct LibraryBrowser: View {
    @Environment(FavoritesStore.self) private var favorites

    @Binding var query: String
    @Binding var filter: LibraryListFilter

    var title: String = "Library"
    var showsCancel: Bool = false
    var showsTopChrome: Bool = true
    var showsIllustrationCredit: Bool = false
    var bottomInset: CGFloat = 24
    var onCancel: (() -> Void)? = nil
    var onSelect: (LibraryWorkout) -> Void

    private var chromeHeight: CGFloat { 48 }
    private var chromeTopPadding: CGFloat { 8 }
    private var chromeBottomGap: CGFloat { 16 }

    private var results: [LibraryWorkout] {
        LibraryCatalog.workouts.filter { workout in
            switch filter {
            case .all:
                break
            case .favorites:
                guard favorites.isLiked(workout.slug) else { return false }
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
                        .foregroundStyle(.white.opacity(0.8))
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
            .padding(
                .top,
                showsTopChrome
                    ? chromeTopPadding + chromeHeight + chromeBottomGap
                    : chromeTopPadding
            )
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
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .navigation)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
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
            if showsTopChrome {
                LibraryFilterSearchChrome(query: $query, filter: $filter)
                    .padding(.horizontal, 16)
                    .padding(.top, chromeTopPadding)
            }
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel?() }
                }
            }
        }
    }

    private var emptyMessage: String {
        if case .favorites = filter {
            return "No favorite workouts yet. Tap the heart on a tile to save one."
        }
        return "No workouts match that search."
    }

    private var illustrationCredit: some View {
        Text(.init("Drawings by Everkinetic, arranged by Bryl Lim. [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .tint(.white.opacity(0.8))
    }
}

/// Filter menu + search field used at the top (add-sheet) or bottom (Library tab).
struct LibraryFilterSearchChrome: View {
    @Binding var query: String
    @Binding var filter: LibraryListFilter
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            if !compact {
                filterMenu
                searchField
            } else {
                searchField
                filterMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                Text("All").tag(LibraryListFilter.all)
                Text("Favorites").tag(LibraryListFilter.favorites)
                ForEach(LibraryCatalog.equipment, id: \.self) { item in
                    Text(item).tag(LibraryListFilter.equipment(item))
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: compact ? 17 : 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: compact ? 44 : 48, height: compact ? 44 : 48)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel(filterAccessibilityLabel)
    }

    private var searchField: some View {
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
        .frame(height: compact ? 44 : 48)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var filterAccessibilityLabel: String {
        switch filter {
        case .all:
            return "Filter, All"
        case .favorites:
            return "Filter, Favorites"
        case .equipment(let item):
            return "Filter by equipment, \(item)"
        }
    }
}

struct LibraryTile: View {
    @Environment(FavoritesStore.self) private var favorites
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
                        .foregroundStyle(.white)
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
                    .foregroundStyle(isLiked ? Color.pink : .white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Remove from favorites" : "Add to favorites")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

#Preview {
    LibraryView()
        .environment(FavoritesStore())
        .environment(WashTheme())
        .preferredColorScheme(.dark)
}
