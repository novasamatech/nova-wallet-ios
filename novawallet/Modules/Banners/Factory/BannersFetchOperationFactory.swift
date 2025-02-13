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
    private let fetchOperationFactory: BaseFetchOperationFactory
    private let imageRetrieveOperationFactory: ImageRetrieveOperationFactory<CommonImageInfo>
    private let operationManager: OperationManagerProtocol

    private var bannersProvider: AnySingleValueProvider<[RemoteBannerModel]>?

    init(
        domain: Banners.Domain,
        bannersContentPath: String,
        fetchOperationFactory: BaseFetchOperationFactory,
        imageRetrieveOperationFactory: ImageRetrieveOperationFactory<CommonImageInfo>,
        operationManager: OperationManagerProtocol
    ) {
        self.domain = domain
        self.bannersContentPath = bannersContentPath
        self.fetchOperationFactory = fetchOperationFactory
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
    func createBannersFetchOperation() -> BaseOperation<[RemoteBannerModel]> {
        guard let url = createURL() else {
            return .createWithError(BannersFetchErrors.badURL)
        }

        return fetchOperationFactory.createFetchOperation(from: url)
    }

    func createImagesFetchOperation(
        with imageInfo: CommonImageInfo,
        imageURLKeyPath: KeyPath<RemoteBannerModel, URL>,
        dependingOn bannerFetchOperation: BaseOperation<[RemoteBannerModel]>
    ) -> BaseOperation<[UIImage]> {
        OperationCombiningService(operationManager: operationManager) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let banners = try bannerFetchOperation.extractNoCancellableResultData()

            let wrappers: [CompoundOperationWrapper<UIImage>] = banners
                .map { banner in
                    self.createImageFetchWrapper(
                        with: imageInfo.byChangingURL(banner[keyPath: imageURLKeyPath])
                    )
                }

            return wrappers
        }.longrunOperation()
    }

    func createImageFetchWrapper(with imageInfo: CommonImageInfo) -> CompoundOperationWrapper<UIImage> {
        guard let cacheKey = imageInfo.url?.absoluteString else {
            return .createWithError(BannersFetchErrors.imageURLIsMissing)
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
        let backgroundImageFetchOperation = createImagesFetchOperation(
            with: backgroundImageInfo,
            imageURLKeyPath: \.background,
            dependingOn: bannersFetchOperation
        )
        let contentImageFetchOperation = createImagesFetchOperation(
            with: contentImageInfo,
            imageURLKeyPath: \.image,
            dependingOn: bannersFetchOperation
        )
        let mapOperation: BaseOperation<[Banner]> = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let remoteBanners = try bannersFetchOperation.extractNoCancellableResultData()
            let backgroundImages = try backgroundImageFetchOperation.extractNoCancellableResultData()
            let contentImages = try contentImageFetchOperation.extractNoCancellableResultData()

            return zip(remoteBanners, zip(backgroundImages, contentImages))
                .map { remoteBanner, images in
                    Banner(
                        id: remoteBanner.id,
                        background: images.0,
                        image: images.1,
                        clipsToBounds: remoteBanner.clipsToBounds,
                        actionLink: remoteBanner.action
                    )
                }
        }

        backgroundImageFetchOperation.addDependency(bannersFetchOperation)
        contentImageFetchOperation.addDependency(bannersFetchOperation)

        let dependencies = [
            bannersFetchOperation,
            backgroundImageFetchOperation,
            contentImageFetchOperation
        ]

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
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

enum BannersFetchErrors: Error {
    case badURL
    case imageURLIsMissing
    case bannersListFetchError
}
