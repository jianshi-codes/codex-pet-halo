struct ApplicationMenuModel: Equatable {
    let applicationName = "Pet Halo"
    let versionText: String

    init(version: AppVersion) {
        versionText = version.displayText
    }
}
