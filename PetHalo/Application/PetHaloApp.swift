import SwiftUI

@main
struct PetHaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let menuModel = ApplicationMenuModel(version: .current())

    var body: some Scene {
        MenuBarExtra(menuModel.applicationName, systemImage: "circle.dashed") {
            Text(menuModel.applicationName)
            Text(menuModel.status)
            Divider()
            Text(menuModel.versionText)
            Divider()
            Button("Quit Pet Halo") {
                appDelegate.coordinator.requestTermination()
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
