import UIKit
import Operation_iOS
import SoraFoundation
import SoraKeystore

final class BannersInteractor {
    weak var presenter: BannersInteractorOutputProtocol?

    private let bannersFactory: BannersFetchOperationFactoryProtocol
    private let localizationFactory: BannersLocalizationFactoryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    init(
        bannersFactory: BannersFetchOperationFactoryProtocol,
        localizationFactory: BannersLocalizationFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.bannersFactory = bannersFactory
        self.localizationFactory = localizationFactory
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: Private

private extension BannersInteractor {
    func fetchBanners(for locale: Locale) {
        let fullFetchWrapper = createFullFetchWrapper(for: locale)

        execute(
            wrapper: fullFetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fetchResult):
                self?.presenter?.didReceive(fetchResult)
            case let .failure(error):
                self?.logger.error("Banners fetch failed with error: \(error)")
                self?.presenter?.didReceive(error)
            }
        }
    }

    func createFullFetchWrapper(for locale: Locale) -> CompoundOperationWrapper<BannersFetchResult> {
        let backgroundImageInfo = CommonImageInfo(
            size: CGSize(width: 343, height: 110),
            scale: UIScreen.main.scale
        )
        let contentImageInfo = CommonImageInfo(
            size: CGSize(width: 126, height: 96),
            scale: UIScreen.main.scale
        )
        let bannersFetchWrapper = bannersFactory.createWrapper(
            backgroundImageInfo: backgroundImageInfo,
            contentImageInfo: contentImageInfo
        )
        let localizationFetchWrapper = localizationFactory.createWrapper(for: locale)

        let mergeOperation: ClosureOperation<BannersFetchResult> = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let banners = try bannersFetchWrapper.targetOperation.extractNoCancellableResultData()
            let localizations = try localizationFetchWrapper.targetOperation.extractNoCancellableResultData()

            return BannersFetchResult(
                banners: banners,
                closedBanners: settingsManager.closedBanners,
                localizedResources: localizations
            )
        }

        mergeOperation.addDependency(bannersFetchWrapper.targetOperation)
        mergeOperation.addDependency(localizationFetchWrapper.targetOperation)

        let dependencies = bannersFetchWrapper.allOperations + localizationFetchWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }
}

// MARK: BannersInteractorInputProtocol

extension BannersInteractor: BannersInteractorInputProtocol {
    func updateResources(for locale: Locale) {
        let localizationFetchWrapper = localizationFactory.createWrapper(for: locale)

        execute(
            wrapper: localizationFetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fetchResult):
                self?.presenter?.didReceive(fetchResult)
            case let .failure(error):
                self?.logger.error("Localization fetch failed with error: \(error)")
                self?.presenter?.didReceive(error)
            }
        }
    }

    func setup(with locale: Locale) {
        fetchBanners(for: locale)
    }

    func refresh(for locale: Locale) {
        fetchBanners(for: locale)
    }

    func closeBanner(with id: String) {
        var closedBanners = settingsManager.closedBanners
        closedBanners.add(id)
        settingsManager.closedBanners = closedBanners

        presenter?.didReceive(closedBanners)
    }
}
