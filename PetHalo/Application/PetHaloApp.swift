import SwiftUI

@main
struct PetHaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let menuModel = ApplicationMenuModel(version: .current())

    var body: some Scene {
        MenuBarExtra(menuModel.applicationName, image: "MenuBarIcon") {
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
        Text(coordinator.cliStatusText)
        Divider()
        Button("Show Halo") {
            coordinator.showHalo()
        }
        .disabled(!coordinator.canShowHalo)

        Button("Hide Halo") {
            coordinator.hideHalo()
        }
        .disabled(!coordinator.haloIsVisible || !coordinator.acceptsUICommands)

        if coordinator.haloSurfaceMode == .petRing {
            Text("Display: Pet Ring")
        } else {
            Button {
                coordinator.setHaloMode(.compact)
            } label: {
                if coordinator.haloMode == .compact {
                    Label("Compact", systemImage: "checkmark")
                } else {
                    Text("Compact")
                }
            }
            .disabled(!coordinator.canChangeHaloMode)

            Button {
                coordinator.setHaloMode(.expanded)
            } label: {
                if coordinator.haloMode == .expanded {
                    Label("Expanded", systemImage: "checkmark")
                } else {
                    Text("Expanded")
                }
            }
            .disabled(!coordinator.canChangeHaloMode)
        }

        Button("Refresh Usage") {
            coordinator.refreshUsage()
        }
        .disabled(!coordinator.canRefreshUsage)
        Divider()
        Text("Position: Fixed")
        Text(coordinator.petStatusText)
        Button("Locate Pet") {
            coordinator.locatePet()
        }
        .disabled(!coordinator.acceptsUICommands)

        Divider()
        Text(menuModel.versionText)
        Divider()
        Button("Quit Pet Halo") {
            coordinator.requestTermination()
        }
        .keyboardShortcut("q")
    }
}
