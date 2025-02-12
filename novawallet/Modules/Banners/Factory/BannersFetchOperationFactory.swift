import Foundation
import UIKit
import Operation_iOS

protocol BannersFetchOperationFactoryProtocol {
    func createWrapper(
        backgroundImageInfo: CommonImageInfo,
        contentImageInfo: CommonImageInfo
    ) -> CompoundOperationWrapper<[Banner]>
}

class BannersFetchOperationFactory {
    private let domain: Banners.Domain
    private let bannersContentPath: String
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    private let imageRetrieveOperationFactory: ImageRetrieveOperationFactory<CommonImageInfo>
    private let operationManager: OperationManagerProtocol

    private var bannersProvider: AnySingleValueProvider<[RemoteBannerModel]>?

    init(
        domain: Banners.Domain,
        bannersContentPath: String,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        imageRetrieveOperationFactory: ImageRetrieveOperationFactory<CommonImageInfo>,
        operationManager: OperationManagerProtocol
    ) {
        self.domain = domain
        self.bannersContentPath = bannersContentPath
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.imageRetrieveOperationFactory = imageRetrieveOperationFactory
        self.operationManager = operationManager
    }

    private func createURL() -> URL? {
        let domainValue = domain.rawValue

        let urlString = bannersContentPath + String(
            format: Constants.bannersFormat,
            domainValue
        )

        return URL(string: urlString)
    }
}

// MARK: Private

private extension BannersFetchOperationFactory {
    func createBannersFetchOperation() -> BaseOperation<[RemoteBannerModel]?> {
        guard let url = createURL() else {
            return .createWithResult(nil)
        }

        let resultClosure: (
            (Result<[RemoteBannerModel]?, Error>)?,
            (Result<[RemoteBannerModel]?, Error>) -> Void
        ) -> Void = { result, closure in
            guard let result else {
                closure(.failure(BaseOperationError.parentOperationCancelled))

                return
            }

            closure(result)
        }

        return AsyncClosureOperation { [weak self] closure in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            if let bannersProvider {
                _ = bannersProvider.fetch { resultClosure($0, closure) }
            } else {
                let provider: AnySingleValueProvider<[RemoteBannerModel]>
                provider = jsonDataProviderFactory.getJson(for: url)

                bannersProvider = provider

                _ = provider.fetch { resultClosure($0, closure) }
            }
        }
    }

    func createImagesFetchWrapper(
        with imageInfo: CommonImageInfo,
        imageURLKeyPath: KeyPath<RemoteBannerModel, URL>,
        dependingOn bannerFetchOperation: BaseOperation<[RemoteBannerModel]?>
    ) -> CompoundOperationWrapper<[String: CompoundOperationWrapper<UIImage>]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let banners = try bannerFetchOperation.extractNoCancellableResultData()

            let innerWrappers: [String: CompoundOperationWrapper<UIImage>] = banners?
                .reduce(into: [:]) { acc, banner in
                    acc[banner.id] = self.createImageFetchWrapper(
                        with: imageInfo.byChangingURL(banner[keyPath: imageURLKeyPath])
                    )
                } ?? [:]

            return .createWithResult(innerWrappers)
        }
    }

    func createImageFetchWrapper(with imageInfo: CommonImageInfo) -> CompoundOperationWrapper<UIImage> {
        guard let cacheKey = imageInfo.url?.absoluteString else {
            return .createWithError(NSError())
        }

        let checkCacheOperation = imageRetrieveOperationFactory.checkCacheOperation(using: cacheKey)

        let wrapper: CompoundOperationWrapper<UIImage> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let cached = try checkCacheOperation.extractNoCancellableResultData()

            let fetchOperation = if cached {
                imageRetrieveOperationFactory.retrieveImageOperation(using: cacheKey)
            } else {
                imageRetrieveOperationFactory.downloadImageOperation(using: imageInfo)
            }

            return CompoundOperationWrapper(targetOperation: fetchOperation)
        }

        wrapper.addDependency(operations: [checkCacheOperation])

        return wrapper.insertingHead(operations: [checkCacheOperation])
    }

    func bannersMapWrapper(
        remoteBanners: [RemoteBannerModel],
        backgroundImageWrappers: [String: CompoundOperationWrapper<UIImage>],
        contentImageWrappers: [String: CompoundOperationWrapper<UIImage>]
    ) -> CompoundOperationWrapper<[Banner]> {
        let mapOperation: BaseOperation<[Banner]> = ClosureOperation {
            try remoteBanners.map {
                let background = try backgroundImageWrappers[$0.id]?
                    .targetOperation
                    .extractNoCancellableResultData()
                let contentImage = try contentImageWrappers[$0.id]?
                    .targetOperation
                    .extractNoCancellableResultData()

                return Banner(
                    id: $0.id,
                    background: background,
                    image: contentImage,
                    clipsToBounds: $0.clipsToBounds,
                    actionLink: $0.action
                )
            }
        }

        let backgroundImageOperations = backgroundImageWrappers.flatMap(\.value.allOperations)
        let contentImageOperations = contentImageWrappers.flatMap(\.value.allOperations)

        backgroundImageOperations.forEach { mapOperation.addDependency($0) }
        contentImageOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: backgroundImageOperations + contentImageOperations
        )
    }
}

// MARK: BannersFetchOperationFactoryProtocol

extension BannersFetchOperationFactory: BannersFetchOperationFactoryProtocol {
    func createWrapper(
        backgroundImageInfo: CommonImageInfo,
        contentImageInfo: CommonImageInfo
    ) -> CompoundOperationWrapper<[Banner]> {
        let bannersFetchOperation = createBannersFetchOperation()
        let backgroundImageFetchOperationsWrapper = createImagesFetchWrapper(
            with: backgroundImageInfo,
            imageURLKeyPath: \.background,
            dependingOn: bannersFetchOperation
        )
        let contentImageFetchOperationsWrapper = createImagesFetchWrapper(
            with: contentImageInfo,
            imageURLKeyPath: \.image,
            dependingOn: bannersFetchOperation
        )

        let resultWrapper: CompoundOperationWrapper<[Banner]>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let remoteBanners = try bannersFetchOperation.extractNoCancellableResultData()
            let backgroundImageWrappers = try backgroundImageFetchOperationsWrapper
                .targetOperation
                .extractNoCancellableResultData()
            let contentImageWrappers = try contentImageFetchOperationsWrapper
                .targetOperation
                .extractNoCancellableResultData()

            return bannersMapWrapper(
                remoteBanners: remoteBanners ?? [],
                backgroundImageWrappers: backgroundImageWrappers,
                contentImageWrappers: contentImageWrappers
            )
        }

        backgroundImageFetchOperationsWrapper.addDependency(operations: [bannersFetchOperation])
        contentImageFetchOperationsWrapper.addDependency(operations: [bannersFetchOperation])

        resultWrapper.addDependency(wrapper: backgroundImageFetchOperationsWrapper)
        resultWrapper.addDependency(wrapper: contentImageFetchOperationsWrapper)

        return resultWrapper
            .insertingHead(operations: [bannersFetchOperation])
            .insertingHead(operations: backgroundImageFetchOperationsWrapper.allOperations)
            .insertingHead(operations: contentImageFetchOperationsWrapper.allOperations)
    }
}

// MARK: Constants

private extension BannersFetchOperationFactory {
    enum Constants {
        static var bannersFormat: String {
            #if F_RELEASE
                "%@/banners.json"
            #else
                "%@/banners_dev.json"
            #endif
        }
    }
}
