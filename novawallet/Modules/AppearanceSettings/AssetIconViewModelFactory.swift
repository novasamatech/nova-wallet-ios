import Foundation
import SoraKeystore

protocol AssetIconViewModelFactoryProtocol {
    func createAssetIcon(
        for iconPath: String?,
        defaultURL: URL?
    ) -> ImageViewModelProtocol
}

extension AssetIconViewModelFactoryProtocol {
    func createAssetIconViewModel(
        for iconPath: String?,
        defaultURL: URL? = nil
    ) -> ImageViewModelProtocol {
        createAssetIcon(
            for: iconPath,
            defaultURL: defaultURL
        )
    }
}

class AssetIconViewModelFactory {
    private let appearanceFacade: AppearanceFacadeProtocol
    private let applicationConfig: ApplicationConfigProtocol

    init(
        appearanceFacade: AppearanceFacadeProtocol = AppearanceFacade.shared,
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared
    ) {
        self.appearanceFacade = appearanceFacade
        self.applicationConfig = applicationConfig
    }
}

// MARK: AssetIconViewModelFactoryProtocol

extension AssetIconViewModelFactory: AssetIconViewModelFactoryProtocol {
    func createAssetIcon(
        for iconPath: String?,
        defaultURL: URL? = nil
    ) -> ImageViewModelProtocol {
        let baseURL: URL? = if let iconPath {
            switch appearanceFacade.selectedIconAppearance {
            case .white:
                URL(string: applicationConfig.whiteAppearanceIconsPath + iconPath)
            case .colored:
                URL(string: applicationConfig.coloredAppearanceIconsPath + iconPath)
            }
        } else {
            defaultURL
        }

        let fallbackImage = R.image.iconDefaultToken()!

        return if let baseURL {
            RemoteImageViewModel(
                url: baseURL,
                fallbackImage: fallbackImage
            )
        } else {
            StaticImageViewModel(image: fallbackImage)
        }
    }
}
