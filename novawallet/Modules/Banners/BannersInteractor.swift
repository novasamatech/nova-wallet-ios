import UIKit
import Operation_iOS
import SoraFoundation
import SoraKeystore

final class BannersInteractor {
    weak var presenter: BannersInteractorOutputProtocol?

    private let domain: Banners.Domain
    private let bannersFactory: BannersFetchOperationFactoryProtocol
    private let localizationFactory: BannersLocalizationFactoryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    private var tmpCloseIds = Set<String>()

    init(
        domain: Banners.Domain,
        bannersFactory: BannersFetchOperationFactoryProtocol,
        localizationFactory: BannersLocalizationFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.domain = domain
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
            size: CGSize(width: 343, height: 126),
            scale: UIScreen.main.scale
        )
        let contentImageInfo = CommonImageInfo(
            size: CGSize(width: 40, height: 40),
            scale: UIScreen.main.scale
        )
        let bannersFetchWrapper = bannersFactory.createWrapper(
            backgroundImageInfo: backgroundImageInfo,
            contentImageInfo: contentImageInfo
        )
        let localizationFetchOperation = localizationFactory.createOperation(for: locale)

        let mergeOperation: ClosureOperation<BannersFetchResult> = ClosureOperation { [weak self] in
            guard
                let self,
                let localizations = try localizationFetchOperation.extractNoCancellableResultData()
            else {
                throw BaseOperationError.parentOperationCancelled
            }

            let banners = try bannersFetchWrapper.targetOperation.extractNoCancellableResultData()

            return BannersFetchResult(
                banners: banners,
                closedBannerIds: settingsManager.closedBannerIds?[domain],
                localizedResources: localizations
            )
        }

        mergeOperation.addDependency(bannersFetchWrapper.targetOperation)
        mergeOperation.addDependency(localizationFetchOperation)

        let dependencies = bannersFetchWrapper.allOperations + [localizationFetchOperation]

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }
}

// MARK: BannersInteractorInputProtocol

extension BannersInteractor: BannersInteractorInputProtocol {
    func updateResources(for locale: Locale) {
        let localizationFetchOperation = localizationFactory.createOperation(for: locale)

        execute(
            operation: localizationFetchOperation,
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
        tmpCloseIds.removeAll()
        fetchBanners(for: locale)
    }

    func closeBanner(with id: String) {
//        var closedBannerIds = settingsManager.closedBannerIds?[domain] ?? Set()
//        closedBannerIds.insert(id)
//
//        var dict = settingsManager.closedBannerIds ?? [:]
//        dict[domain] = closedBannerIds
//
//        settingsManager.closedBannerIds = dict
        tmpCloseIds.insert(id)

        presenter?.didReceive(tmpCloseIds)
    }
}
