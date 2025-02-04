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
    func createFullFetchWrapper(for locale: Locale) -> CompoundOperationWrapper<BannersFetchResult> {
        let bannersFetchWrapper = bannersFactory.createWrapper()
        let localizationFetchWrapper = localizationFactory.createWrapper(for: locale)

        let mergeOperation: ClosureOperation<BannersFetchResult> = ClosureOperation {
            guard
                let banners = try bannersFetchWrapper.targetOperation.extractNoCancellableResultData(),
                let localizations = try localizationFetchWrapper.targetOperation.extractNoCancellableResultData()
            else {
                throw BaseOperationError.parentOperationCancelled
            }

            return BannersFetchResult(
                banners: banners,
                localizedResources: localizations
            )
        }

        mergeOperation.addDependency(bannersFetchWrapper.targetOperation)
        mergeOperation.addDependency(localizationFetchWrapper.targetOperation)

        return bannersFetchWrapper
            .insertingTail(operation: mergeOperation)
            .insertingHead(operations: localizationFetchWrapper.allOperations)
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
                self?.presenter?.didReceive(error)
            }
        }
    }

    func setup(with locale: Locale) {
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
}
