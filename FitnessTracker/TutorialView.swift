import SwiftUI

struct ExerciseTutorial: Hashable {
    let name: String
    let muscles: String
    let frames: [String]
    let hints: [String]
    let hintSource: String?
    let favoriteSlug: String?
}

struct ExerciseTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FavoritesStore.self) private var favorites
    let exerciseName: String
    let muscles: String
    let grade: WashGrade
    let frames: [String]
    let hints: [String]
    let hintSource: String?
    var favoriteSlug: String? = nil

    private var canFavorite: Bool { favoriteSlug != nil }
    private var isLiked: Bool {
        guard let favoriteSlug else { return false }
        return favorites.isLiked(favoriteSlug)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(exerciseName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(muscles)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                cyclingHero
                    .padding(.top, 24)

                Text("Tips & Hints")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 48)

                if let hintSource, !hints.isEmpty {
                    Text("Source: \(hintSource)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 8)
                }

                VStack(spacing: 12) {
                    ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                        hintCard(hint)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 42)
        }
        .scrollContentBackground(.hidden)
        .foregroundStyle(.white)
        .background {
            ZStack {
                Color.black
                WashBackground(grade: grade)
            }
            .ignoresSafeArea()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationTitle("Tutorial")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            .sharedBackgroundVisibility(.hidden)

            if canFavorite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let favoriteSlug else { return }
                        favorites.toggle(favoriteSlug)
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isLiked ? Color.pink : .white)
                            .frame(width: 48, height: 48)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isLiked ? "Remove from favorites" : "Add to favorites")
                }
                .sharedBackgroundVisibility(.hidden)
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
        .background {
            DisableRoutineInteractivePop()
        }
    }

    private var cyclingHero: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let index = frames.isEmpty
                ? 0
                : Int(context.date.timeIntervalSinceReferenceDate / 0.45) % frames.count
            IllustrationView(slug: frames[index], label: exerciseName)
                .padding(28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 370)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func hintCard(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
            Text(hint)
                .font(.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
