import SwiftUI

struct IllustrationView: View {
    let slug: String
    let label: String
    var fill: Bool = false

    var body: some View {
        Image(slug)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: fill ? .fill : .fit)
            .foregroundStyle(.primary)
            .accessibilityLabel(label)
    }
}
