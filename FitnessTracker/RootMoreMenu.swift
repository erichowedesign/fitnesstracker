import SwiftUI

/// Top-trailing ellipsis menu. Sectioned so new preferences can land beside Glass later.
struct RootMoreMenu: View {
    @Environment(GlassModeStore.self) private var glassModeStore

    var body: some View {
        @Bindable var glassModeStore = glassModeStore
        Menu {
            Section("Glass") {
                Picker("Glass", selection: $glassModeStore.mode) {
                    ForEach(GlassMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }
}
