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
        .disabled(!coordinator.canShowHalo)

        Button("Hide Halo") {
            coordinator.hideHalo()
        }
        .disabled(!coordinator.haloIsVisible || !coordinator.acceptsUICommands)

        if coordinator.haloSurfaceMode == .petRing {
            Text("Display: Pet Ring")
            if coordinator.isAdjustingPetRingCenter {
                Text("Drag the Ring or use 4 pt nudges")
                Button("Nudge Up") {
                    coordinator.nudgePetRing(horizontal: 0, vertical: 4)
                }
                Button("Nudge Down") {
                    coordinator.nudgePetRing(horizontal: 0, vertical: -4)
                }
                Button("Nudge Left") {
                    coordinator.nudgePetRing(horizontal: -4, vertical: 0)
                }
                Button("Nudge Right") {
                    coordinator.nudgePetRing(horizontal: 4, vertical: 0)
                }
                Button("Save Ring Center") {
                    coordinator.finishWindowFollowingCalibration()
                }
                Button("Cancel Ring Center Adjustment") {
                    coordinator.cancelWindowFollowingCalibration()
                }
                Button("Reset Visual Center") {
                    coordinator.resetPetVisualCenter()
                }
            } else {
                Button("Adjust Ring Center") {
                    coordinator.beginPetFollowingCalibration()
                }
                .disabled(!coordinator.canFineTunePetRing)
                Button("Reset Visual Center") {
                    coordinator.resetPetVisualCenter()
                }
                .disabled(!coordinator.canFineTunePetRing)
            }

            #if DEBUG
            Menu("Orientation Preview") {
                ForEach(PetRingOrientationPreview.allCases, id: \.self) { preview in
                    Button {
                        coordinator.setPetRingOrientationPreview(preview)
                    } label: {
                        if coordinator.petRingOrientationPreview == preview {
                            Label(preview.label, systemImage: "checkmark")
                        } else {
                            Text(preview.label)
                        }
                    }
                }
            }
            #endif
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
        Text(coordinator.targetStatusText)
        Text(coordinator.petStatusText)
        Text(coordinator.petPlacementStatusText)
        Text(coordinator.followingStatusText)

        Button("Enable Pet Following") {
            coordinator.enablePetFollowing()
        }
        .disabled(!coordinator.canEnablePetFollowing)

        Button("Calibrate Codex Window Fallback") {
            coordinator.beginWindowFallbackCalibration()
        }
        .disabled(!coordinator.canCalibrateWindowFallback)

        Button("Finish Window Calibration") {
            coordinator.finishWindowFollowingCalibration()
        }
        .disabled(!coordinator.canFinishCalibration || coordinator.isAdjustingPetRingCenter)

        Button("Cancel Window Calibration") {
            coordinator.cancelWindowFollowingCalibration()
        }
        .disabled(!coordinator.canFinishCalibration || coordinator.isAdjustingPetRingCenter)

        Button("Use Codex Window Fallback") {
            coordinator.useWindowFallback()
        }
        .disabled(!coordinator.canUseWindowFallback)

        Button("Disable Following") {
            coordinator.disableWindowFollowing()
        }
        .disabled(!coordinator.canDisableWindowFollowing)

        Divider()
        Text(menuModel.versionText)
        Divider()
        Button("Quit Pet Halo") {
            coordinator.requestTermination()
        }
        .keyboardShortcut("q")
    }
}
