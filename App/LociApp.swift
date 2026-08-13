import SwiftUI
import LociCore

/// Composition root for the multiplatform Loci app.
/// Wires concrete services into the environment (PR04+). Features must not import each other.
@main
struct LociApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            PlaceholderRootView()
                .environment(services)
        }
    }
}

/// Temporary first-launch surface until PR02/PR03 ship design system + shell.
struct PlaceholderRootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Loci")
                .font(.largeTitle.weight(.bold))
            Text("Local-first object PKM. Vault is truth; index is local.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
