import SwiftUI
import UniformTypeIdentifiers

private enum HomeRoute: Hashable {
    case create
    case routine(String)
}

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(RoutineOverridesStore.self) private var routineOverrides
    @Environment(CustomRoutinesStore.self) private var customRoutines
    @Environment(RoutineOrderStore.self) private var routineOrder
    @Environment(WashTheme.self) private var wash
    @Environment(\.glassPalette) private var palette
    @Binding var hidesFloatingTabBar: Bool
    @State private var path: [HomeRoute] = []
    /// Routine ids that should open straight into edit mode (new custom creates).
    @State private var startEditingIDs: Set<String> = []
    @State private var isReordering = false
    @State private var draftOrder: [Routine] = []
    @State private var orderSnapshot: [Routine] = []
    @State private var draggingRoutineID: String?
    @State private var pendingDelete: Routine?
    @State private var showDeleteConfirm = false

    init(hidesFloatingTabBar: Binding<Bool> = .constant(false)) {
        _hidesFloatingTabBar = hidesFloatingTabBar
    }

    /// Shipping A–D only — drives Up Next rotation (unchanged by list reorder).
    private var shippingRoutines: [Routine] {
        WorkoutPlan.all().map(routineOverrides.resolved)
    }

    private var customList: [Routine] {
        customRoutines.routines(startingRotationAt: shippingRoutines.count + 1)
    }

    private var upNext: Routine {
        store.nextRoutine(in: shippingRoutines)
    }

    /// Full My Routines list in persisted order (shipping + customs).
    private var orderedRoutines: [Routine] {
        routineOrder.ordered(shipping: shippingRoutines, customs: customList)
    }

    private var displayedRoutines: [Routine] {
        isReordering ? draftOrder : orderedRoutines
    }

    private var upNextListNumber: Int {
        (orderedRoutines.firstIndex { $0.id == upNext.id } ?? 0) + 1
    }

    /// Clears the floating tab bar; matches History’s bottom scroll inset.
    private var homeScrollBottomInset: CGFloat { 120 }

    var body: some View {
        NavigationStack(path: $path) {
            homeScroll
        }
    }

    private var homeScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Get to Work")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .glassInk()
                Text("You got a lot of shit to get done")
                    .font(.body)
                    .glassInk()
                    .padding(.top, 8)

                Text("Up Next")
                    .font(.title2)
                    .fontWeight(.bold)
                    .glassInk()
                    .padding(.top, 48)

                Button {
                    guard !isReordering else { return }
                    openRoutine(upNext)
                } label: {
                    UpNextCard(routine: upNext, listNumber: upNextListNumber)
                }
                .buttonStyle(.plain)
                .disabled(isReordering)
                .padding(.top, 24)

                HStack(alignment: .center, spacing: 12) {
                    Text("My Routines")
                        .font(.title2)
                        .fontWeight(.bold)
                        .glassInk()
                    Spacer(minLength: 0)
                    if !isReordering {
                        GlassChromeIconButton(
                            systemName: "plus",
                            accessibilityLabel: "Create routine",
                            size: 48,
                            action: {
                                path.append(.create)
                                hidesFloatingTabBar = true
                            }
                        )
                    }
                }
                .padding(.top, 48)

                VStack(spacing: 12) {
                    ForEach(Array(displayedRoutines.enumerated()), id: \.element.id) { index, routine in
                        routineTile(routine, listNumber: index + 1)
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 16)
            // Match Routine / Tutorial large-title top inset.
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .contentMargins(.bottom, homeScrollBottomInset, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectHidden(true, for: .vertical)
        .glassInk()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .navigation)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .preferredColorScheme(palette.colorScheme)
        .animation(.smooth(duration: 0.3), value: palette.mode)
        .animation(.smooth(duration: 0.28), value: isReordering)
        .background { LockRootPopGesture() }
        .navigationTitle("Foundation")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isReordering)
        .toolbar { homeToolbar }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .create:
                CreateRoutineView { routine in
                    startEditingIDs.insert(routine.id)
                    // Replace create with the new routine so Back from edit returns Home.
                    path = [.routine(routine.id)]
                }
            case .routine(let id):
                if let routine = resolvedRoutine(id: id) {
                    RoutineView(
                        routine: routine,
                        startsInEditMode: startEditingIDs.contains(id)
                    )
                    .onDisappear {
                        startEditingIDs.remove(id)
                    }
                } else {
                    Text("Routine unavailable")
                        .glassInk()
                        .onAppear { path.removeAll() }
                }
            }
        }
        .onChange(of: path) { _, newPath in
            hidesFloatingTabBar = !newPath.isEmpty
        }
        .onAppear {
            wash.grade = .grayscale
        }
        .alert(
            "Delete routine?",
            isPresented: $showDeleteConfirm,
            presenting: pendingDelete
        ) { routine in
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteCustom(routine)
            }
        } message: { routine in
            Text("“\(routine.name)” will be removed from My Routines. This can’t be undone.")
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
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        if isReordering {
            ToolbarItem(placement: .topBarLeading) {
                GlassChromeIconButton(
                    systemName: "xmark",
                    accessibilityLabel: "Cancel reorder",
                    action: cancelReorder
                )
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                GlassChromeIconButton(
                    systemName: "checkmark",
                    accessibilityLabel: "Save order",
                    action: commitReorder
                )
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) {
                Text("Foundation")
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func routineTile(_ routine: Routine, listNumber: Int) -> some View {
        let card = RoutineListCard(
            routine: routine,
            listNumber: listNumber,
            showsDragHandle: isReordering
        )

        if isReordering {
            card
                .onDrag {
                    draggingRoutineID = routine.id
                    return NSItemProvider(object: routine.id as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: HomeReorderDropDelegate(
                        itemID: routine.id,
                        items: $draftOrder,
                        draggingID: $draggingRoutineID
                    )
                )
        } else {
            // contextMenu on the card (not inside Button) so long-press owns the hold;
            // tap still opens the routine.
            card
                .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .onTapGesture {
                    openRoutine(routine)
                }
                .contextMenu {
                    if routine.isCustom || customRoutines.contains(routine.id) {
                        Button("Delete", role: .destructive) {
                            pendingDelete = routine
                            showDeleteConfirm = true
                        }
                    }
                    Button("Reorder") {
                        beginReorder()
                    }
                }
        }
    }

    private func beginReorder() {
        orderSnapshot = orderedRoutines
        draftOrder = orderedRoutines
        withAnimation(.smooth(duration: 0.28)) {
            isReordering = true
        }
    }

    private func commitReorder() {
        routineOrder.save(draftOrder.map(\.id))
        draggingRoutineID = nil
        withAnimation(.smooth(duration: 0.28)) {
            isReordering = false
        }
    }

    private func cancelReorder() {
        draftOrder = orderSnapshot
        draggingRoutineID = nil
        withAnimation(.smooth(duration: 0.28)) {
            isReordering = false
        }
    }

    private func deleteCustom(_ routine: Routine) {
        customRoutines.delete(id: routine.id)
        routineOrder.remove(id: routine.id)
        pendingDelete = nil
    }

    private func openRoutine(_ routine: Routine) {
        hidesFloatingTabBar = true
        path.append(.routine(routine.id))
    }

    private func resolvedRoutine(id: String) -> Routine? {
        if let custom = customRoutines.routine(id: id) {
            return custom
        }
        return shippingRoutines.first { $0.id == id }
    }
}

/// Reorders Home tiles while a glass drag handle is dragged across neighbors.
private struct HomeReorderDropDelegate: DropDelegate {
    let itemID: String
    @Binding var items: [Routine]
    @Binding var draggingID: String?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != itemID,
              let from = items.firstIndex(where: { $0.id == draggingID }),
              let to = items.firstIndex(where: { $0.id == itemID })
        else { return }
        withAnimation(.snappy(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// Apple concentric corners: innerRadius = tile 34 − gap to the illustration square.
private func homeIllustrationThumb(gap: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: 34 - gap, style: .continuous)
}

private struct UpNextCard: View {
    let routine: Routine
    var listNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                WashWindow(grade: WashGrade.forRoutine(routine.id))
                IllustrationView(slug: routine.heroSlug, label: routine.name)
                    .frame(width: 192, height: 192)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .glassInk()
                Text("Routine \(listNumber)")
                    .font(.subheadline)
                    .glassInk()
                    .padding(.top, 16)
                    .padding(.leading, 32)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 216)
            .clipped()

            VStack(alignment: .leading, spacing: 0) {
                Text(routine.name)
                    .font(.system(size: 28, weight: .bold))
                    .frame(height: 34, alignment: .leading)
                Text(routine.focus)
                    .font(.body)
                    .padding(.top, 4)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 8) {
                    Text("\(routine.exerciseCountLabel) workouts / \(routine.minutes) minutes /")
                        .font(.subheadline)
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.white)
                                .frame(width: 4, height: 14)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassInk()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 358)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.name), \(routine.focus), \(routine.workoutsLine)")
    }
}

private struct RoutineListCard: View {
    let routine: Routine
    var listNumber: Int
    var showsDragHandle: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                ZStack {
                    WashWindow(grade: WashGrade.forRoutine(routine.id))
                        .clipShape(homeIllustrationThumb(gap: 16))
                    IllustrationView(slug: routine.heroSlug, label: routine.name)
                        .frame(width: 120, height: 120)
                }
                .frame(width: 120, height: 120)
                .clipShape(homeIllustrationThumb(gap: 16))
                .glassInk()
                VStack(alignment: .leading, spacing: 23) {
                    Text("Routine \(listNumber)")
                        .font(.system(size: 15))
                        .frame(height: 18, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(height: 25, alignment: .leading)
                            .lineLimit(1)
                        Text(routine.focus)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassInk()
            }

            if showsDragHandle {
                GlassChromeSymbolCircle(
                    systemName: "line.3.horizontal",
                    accessibilityLabel: "Reorder",
                    size: 32
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine \(listNumber), \(routine.name), \(routine.focus)")
    }
}

#Preview {
    HomeView()
    .environment(SessionStore())
    .environment(RoutineOverridesStore())
    .environment(CustomRoutinesStore())
    .environment(RoutineOrderStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
