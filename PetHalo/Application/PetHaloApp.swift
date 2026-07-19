import SwiftUI

@main
struct PetHaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let menuModel = ApplicationMenuModel(version: .current())

    var body: some Scene {
        MenuBarExtra(menuModel.applicationName, systemImage: "circle.dashed") {
            ApplicationMenuContent(
                coordinator: appDelegate.coordinator,
                menuModel: menuModel
            )
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct ApplicationMenuContent: View {
    @ObservedObject var coordinator: ApplicationCoordinator
    let menuModel: ApplicationMenuModel

    var body: some View {
        Text(menuModel.applicationName)
        Text(coordinator.bridgeStatusText)
        Divider()
        Button("Show Halo") {
            coordinator.showHalo()
        }
        .disabled(coordinator.haloIsVisible || !coordinator.acceptsUICommands)

        Button("Hide Halo") {
            coordinator.hideHalo()
        }
        .disabled(!coordinator.haloIsVisible || !coordinator.acceptsUICommands)

        Button {
            coordinator.setHaloMode(.compact)
        } label: {
            if coordinator.haloMode == .compact {
                Label("Compact", systemImage: "checkmark")
            } else {
                Text("Compact")
            }
        }
        .disabled(!coordinator.acceptsUICommands)

        Button {
            coordinator.setHaloMode(.expanded)
        } label: {
            if coordinator.haloMode == .expanded {
                Label("Expanded", systemImage: "checkmark")
            } else {
                Text("Expanded")
            }
        }
        .disabled(!coordinator.acceptsUICommands)

        Button("Refresh Usage") {
            coordinator.refreshUsage()
        }
        .disabled(!coordinator.canRefreshUsage)
        Divider()
        Text(menuModel.versionText)
        Divider()
        Button("Quit Pet Halo") {
            coordinator.requestTermination()
        }
        .keyboardShortcut("q")
    }
}
