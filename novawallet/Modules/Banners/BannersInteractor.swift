import UIKit
import Operation_iOS
import Foundation_iOS
import Keystore_iOS

final class BannersInteractor {
    weak var presenter: BannersInteractorOutputProtocol?

    private let bannersFactory: BannersFetchOperationFactoryProtocol
    private let localizationFactory: BannersLocalizationFactoryProtocol
    private let bittensorSource: BittensorLocalBannerSourceProtocol?
    private let textHeightOperationFactory: TextHeightOperationFactoryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    private let bittensorContentCallStore = CancellableCallStore()
    private var bittensorBanner: BittensorLocalBanner?
    private var locale: Locale?
    private var availableTextWidth: CGFloat?

    init(
        bannersFactory: BannersFetchOperationFactoryProtocol,
        localizationFactory: BannersLocalizationFactoryProtocol,
        bittensorSource: BittensorLocalBannerSourceProtocol?,
        textHeightOperationFactory: TextHeightOperationFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.bannersFactory = bannersFactory
        self.localizationFactory = localizationFactory
        self.bittensorSource = bittensorSource
        self.textHeightOperationFactory = textHeightOperationFactory
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        bittensorContentCallStore.cancel()
    }
}

// MARK: Private

private extension BannersInteractor {
    func fetchBanners(
        for locale: Locale,
        availableTextWidth: CGFloat
    ) {
        let fullFetchWrapper = createFullFetchWrapper(
            for: locale,
            availableTextWidth: availableTextWidth
        )

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

    func createFullFetchWrapper(
        for locale: Locale,
        availableTextWidth: CGFloat
    ) -> CompoundOperationWrapper<BannersFetchResult> {
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
        let localizationFetchWrapper = localizationFactory.createWrapper(
            for: locale,
            availableWidth: availableTextWidth
        )

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

    func store(locale: Locale, availableTextWidth: CGFloat) {
        self.locale = locale
        self.availableTextWidth = availableTextWidth
    }

    func provideBittensorContent() {
        bittensorContentCallStore.cancel()

        guard let bittensorBanner, let locale, let availableTextWidth else {
            presenter?.didReceive(bittensorContent: nil)
            return
        }

        let texts = bittensorBanner.createTexts(for: locale)

        let heightOperation = textHeightOperationFactory.createOperation(
            for: .banner(text: [texts.title, texts.details], availableWidth: availableTextWidth)
        )

        executeCancellable(
            wrapper: CompoundOperationWrapper(targetOperation: heightOperation),
            inOperationQueue: operationQueue,
            backingCallIn: bittensorContentCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(height):
                let content = bittensorBanner.createContent(
                    title: texts.title,
                    details: texts.details,
                    estimatedHeight: height
                )

                self?.presenter?.didReceive(bittensorContent: content)
            case let .failure(error):
                self?.logger.error("Bittensor banner height failed with error: \(error)")
            }
        }
    }
}

// MARK: BannersInteractorInputProtocol

extension BannersInteractor: BannersInteractorInputProtocol {
    func updateResources(
        for locale: Locale,
        availableTextWidth: CGFloat
    ) {
        store(locale: locale, availableTextWidth: availableTextWidth)

        let localizationFetchWrapper = localizationFactory.createWrapper(
            for: locale,
            availableWidth: availableTextWidth
        )

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

        if bittensorBanner != nil {
            provideBittensorContent()
        }
    }

    func setup(
        with locale: Locale,
        availableTextWidth: CGFloat
    ) {
        store(locale: locale, availableTextWidth: availableTextWidth)

        fetchBanners(
            for: locale,
            availableTextWidth: availableTextWidth
        )

        bittensorSource?.delegate = self
        bittensorSource?.setup()
    }

    func refresh(
        for locale: Locale,
        availableTextWidth: CGFloat
    ) {
        store(locale: locale, availableTextWidth: availableTextWidth)

        fetchBanners(
            for: locale,
            availableTextWidth: availableTextWidth
        )

        bittensorSource?.refresh()
    }

    func closeBanner(with id: String) {
        var closedBanners = settingsManager.closedBanners
        closedBanners.add(id)
        settingsManager.closedBanners = closedBanners

        presenter?.didReceive(closedBanners)
    }
}

extension BannersInteractor: BittensorLocalBannerSourceDelegate {
    func bittensorLocalBannerSource(didResolve banner: BittensorLocalBanner?) {
        bittensorBanner = banner
        provideBittensorContent()
    }
}
