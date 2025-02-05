import UIKit
import Operation_iOS
import SoraFoundation

final class BannersInteractor {
    weak var presenter: BannersInteractorOutputProtocol?

    private let bannersFactory: BannersFetchOperationFactoryProtocol
    private let localizationFactory: BannersLocalizationFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        bannersFactory: BannersFetchOperationFactoryProtocol,
        localizationFactory: BannersLocalizationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.bannersFactory = bannersFactory
        self.localizationFactory = localizationFactory
        self.operationQueue = operationQueue
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

        let mergeOperation: ClosureOperation<BannersFetchResult> = ClosureOperation {
            guard let localizations = try localizationFetchOperation.extractNoCancellableResultData() else {
                throw BaseOperationError.parentOperationCancelled
            }

            let banners = try bannersFetchWrapper.targetOperation.extractNoCancellableResultData()

            return BannersFetchResult(
                banners: banners,
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
}
