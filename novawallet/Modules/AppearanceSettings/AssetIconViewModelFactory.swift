import Foundation
import Keystore_iOS

protocol AssetIconViewModelFactoryProtocol {
    func createAssetIcon(
        for iconPath: String?,
        with appearance: AppearanceIconsOptions?,
        defaultURL: URL?
    ) -> ImageViewModelProtocol
}

extension AssetIconViewModelFactoryProtocol {
    func createAssetIconViewModel(
        for iconPath: String?,
        with appearance: AppearanceIconsOptions? = nil,
        defaultURL: URL? = nil
    ) -> ImageViewModelProtocol {
        createAssetIcon(
            for: iconPath,
            with: appearance,
            defaultURL: defaultURL
        )
    }

    func createAssetIconViewModel(from assetDisplayInfo: AssetBalanceDisplayInfo) -> ImageViewModelProtocol {
        createAssetIconViewModel(
            for: assetDisplayInfo.icon?.getPath(),
            defaultURL: assetDisplayInfo.icon?.getURL()
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
        with appearance: AppearanceIconsOptions?,
        defaultURL: URL? = nil
    ) -> ImageViewModelProtocol {
        let selectedAppearance = appearance ?? appearanceFacade.selectedIconAppearance

        let baseURL: URL? = if let iconPath {
            switch selectedAppearance {
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
