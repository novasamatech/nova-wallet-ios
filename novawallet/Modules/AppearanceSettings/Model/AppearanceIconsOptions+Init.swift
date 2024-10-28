extension AppearanceIconsOptions {
    init(from viewSelectedOption: AppearanceSettingsIconsView.AppearanceOptions) {
        switch viewSelectedOption {
        case .white:
            self = .white
        case .colored:
            self = .colored
        }
    }
}
