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

        Button("Refresh Usage") {
            coordinator.refreshUsage()
        }
        .disabled(!coordinator.canRefreshUsage)
        Divider()
        Text(coordinator.targetStatusText)
        Text(coordinator.petStatusText)
        Text(coordinator.followingStatusText)

        Button("Enable Pet Following") {
            coordinator.enablePetFollowing()
        }
        .disabled(!coordinator.canEnablePetFollowing)

        Button("Calibrate Pet Position") {
            coordinator.beginPetFollowingCalibration()
        }
        .disabled(!coordinator.canCalibratePetFollowing)

        Button("Calibrate Codex Window Fallback") {
            coordinator.beginWindowFallbackCalibration()
        }
        .disabled(!coordinator.canCalibrateWindowFallback)

        Button("Finish Calibration") {
            coordinator.finishWindowFollowingCalibration()
        }
        .disabled(!coordinator.canFinishCalibration)

        Button("Cancel Calibration") {
            coordinator.cancelWindowFollowingCalibration()
        }
        .disabled(!coordinator.canFinishCalibration)

        Button("Use Codex Window Fallback") {
            coordinator.useWindowFallback()
        }
        .disabled(!coordinator.canUseWindowFallback)

        Button("Disable Following") {
            coordinator.disableWindowFollowing()
        }
        .disabled(!coordinator.canDisableWindowFollowing)

        Button("Reset Pet Position") {
            coordinator.resetPetPosition()
        }
        .disabled(!coordinator.canResetPetPosition)
        Divider()
        Text(menuModel.versionText)
        Divider()
        Button("Quit Pet Halo") {
            coordinator.requestTermination()
        }
        .keyboardShortcut("q")
    }
}
