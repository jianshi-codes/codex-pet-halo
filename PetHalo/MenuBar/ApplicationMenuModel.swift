struct ApplicationMenuModel: Equatable {
    let applicationName = "Pet Halo"
    let status = "Application skeleton"
    let versionText: String

    init(version: AppVersion) {
        versionText = version.displayText
    }
}
