enum DAppGlobalSettingsViewModel: Hashable {
    case desktopModel(DesktopModel)

    struct DesktopModel: Hashable {
        let title: TitleIconViewModel
        let isOn: Bool
    }
}
