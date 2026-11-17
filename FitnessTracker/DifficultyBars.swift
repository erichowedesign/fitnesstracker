import SwiftUI

struct DifficultyBars: View {
    var filled: Int = 3
    var total: Int = 5

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.white.opacity(index < filled ? 1 : 0.35))
                    .frame(width: 8, height: 31)
            }
        }
        .accessibilityHidden(true)
    }
}
