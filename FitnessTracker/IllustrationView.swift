import SwiftUI

struct IllustrationView: View {
    let slug: String
    let label: String

    var body: some View {
        Image(slug)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .accessibilityLabel(label)
    }
}
