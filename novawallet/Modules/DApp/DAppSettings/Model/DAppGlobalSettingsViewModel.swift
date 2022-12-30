enum DAppGlobalSettingsViewModel: Hashable {
    case favorite(TitleIconViewModel)
    case desktopModel(DesktopModel)

    struct DesktopModel: Hashable {
        let title: TitleIconViewModel
        let isOn: Bool
    }
}
