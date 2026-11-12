import SwiftUI

struct ExerciseTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    let muscles: String
    let grade: WashGrade
    let frames: [String]
    let hints: [String]

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
        Group {
            if frames.count == 3 {
                BenchPressMorphView(slugs: frames, label: exerciseName)
                    .padding(28)
            } else {
                IllustrationView(slug: frames.first ?? "", label: exerciseName)
                    .padding(28)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 370)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
