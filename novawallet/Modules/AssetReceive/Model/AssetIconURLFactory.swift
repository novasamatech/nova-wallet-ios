import Foundation

enum AssetIconURLFactory {
    static func createURL(
        for iconName: String?,
        iconAppearance: AppearanceIconsOptions
    ) -> URL? {
        guard let iconName else { return nil }

        return switch iconAppearance {
        case .white:
            URL(string: ApplicationConfig.shared.whiteAppearanceIconsPath + iconName)
        case .colored:
            URL(string: ApplicationConfig.shared.coloredAppearanceIconsPath + iconName)
        }
    }

    static func createQRLogoURL(
        for iconName: String?,
        iconAppearance: AppearanceIconsOptions
    ) -> IconType? {
        guard let iconName else { return nil }

        switch iconAppearance {
        case .white:
            let path = ApplicationConfig.shared.whiteAppearanceIconsPath
            let url = URL(string: path + iconName)

            return .remoteTransparent(url)
        case .colored:
            let path = ApplicationConfig.shared.coloredAppearanceIconsPath
            let url = URL(string: path + iconName)

            return .remoteColored(url)
        }
    }
}
