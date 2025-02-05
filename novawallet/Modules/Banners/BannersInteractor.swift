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
        let bannersFetchOperation = bannersFactory.createOperation()
        let localizationFetchOperation = localizationFactory.createOperation(for: locale)

        let mergeOperation: ClosureOperation<BannersFetchResult> = ClosureOperation {
            guard
                let banners = try bannersFetchOperation.extractNoCancellableResultData(),
                let localizations = try localizationFetchOperation.extractNoCancellableResultData()
            else {
                throw BaseOperationError.parentOperationCancelled
            }

            return BannersFetchResult(
                banners: banners,
                localizedResources: localizations
            )
        }

        mergeOperation.addDependency(bannersFetchOperation)
        mergeOperation.addDependency(localizationFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [bannersFetchOperation, localizationFetchOperation]
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
