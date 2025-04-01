import Foundation
import Operation_iOS

protocol BannersLocalizationFactoryProtocol {
    func createWrapper(
        for locale: Locale,
        availableWidth: CGFloat
    ) -> CompoundOperationWrapper<BannersLocalizedResources>
}

class BannersLocalizationFactory {
    private let domain: Banners.Domain
    private let bannersContentPath: String
    private let fetchOperationFactory: BaseFetchOperationFactory
    private let textHeightOperationFactory: TextHeightOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    private var localizationProvider: AnySingleValueProvider<BannersLocalizedResources>?

    init(
        domain: Banners.Domain,
        bannersContentPath: String,
        fetchOperationFactory: BaseFetchOperationFactory,
        textHeightOperationFactory: TextHeightOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.domain = domain
        self.bannersContentPath = bannersContentPath
        self.fetchOperationFactory = fetchOperationFactory
        self.textHeightOperationFactory = textHeightOperationFactory
        self.operationManager = operationManager
    }
}

// MARK: Private

private extension BannersLocalizationFactory {
    func createLocalizationURL(for locale: Locale) -> URL? {
        guard let languageCode = locale.languageCode else { return nil }

        let domainValue = domain.rawValue
        let filePathComponent = "\(languageCode).json"

        let pathComponents = [
            domainValue,
            Constants.localizationPath,
            filePathComponent
        ]

        let path = NSString.path(withComponents: pathComponents)
        let urlString = (bannersContentPath as NSString).appendingPathComponent(path)

        return URL(string: urlString)
    }

    func createSingleBannerMapWrapper(
        bannerId: String,
        resources: BannerLocalizedResourcesResponse,
        availableWidth: CGFloat
    ) -> CompoundOperationWrapper<BannersLocalizedResource> {
        let text = [
            resources.title,
            resources.details
        ]
        let estimationOperation = textHeightOperationFactory.createOperation(
            for: .banner(text: text, availableWidth: availableWidth)
        )

        let mappingOperation = ClosureOperation<BannersLocalizedResource> {
            let height = try estimationOperation.extractNoCancellableResultData()

            return BannersLocalizedResource(
                bannerId: bannerId,
                title: resources.title,
                details: resources.details,
                estimatedHeight: height
            )
        }

        mappingOperation.addDependency(estimationOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [estimationOperation]
        )

        return wrapper
    }

    func createMapWrapper(
        dependingOn fetchOperation: BaseOperation<BannersLocalizedResourcesResponse>,
        availableWidth: CGFloat
    ) -> BaseOperation<[BannersLocalizedResource]> {
        OperationCombiningService(operationManager: operationManager) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let localizedResources = try fetchOperation.extractNoCancellableResultData()

            return localizedResources.map {
                self.createSingleBannerMapWrapper(
                    bannerId: $0.key,
                    resources: $0.value,
                    availableWidth: availableWidth
                )
            }
        }.longrunOperation()
    }
}

// MARK: BannersLocalizationFactoryProtocol

extension BannersLocalizationFactory: BannersLocalizationFactoryProtocol {
    func createWrapper(
        for locale: Locale,
        availableWidth: CGFloat
    ) -> CompoundOperationWrapper<BannersLocalizedResources> {
        guard let url = createLocalizationURL(for: locale) else {
            return .createWithError(BannersLocalizationFetchErrors.badURL)
        }

        let fetchOperation: BaseOperation<BannersLocalizedResourcesResponse>
        fetchOperation = fetchOperationFactory.createFetchOperation(from: url)

        let mapOperation = createMapWrapper(
            dependingOn: fetchOperation,
            availableWidth: availableWidth
        )

        mapOperation.addDependency(fetchOperation)

        let resultOperation = ClosureOperation<BannersLocalizedResources> {
            let mappedResources = try mapOperation.extractNoCancellableResultData()

            return mappedResources.reduce(into: [:]) { $0[$1.bannerId] = $1 }
        }

        resultOperation.addDependency(mapOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [fetchOperation, mapOperation]
        )
    }
}

// MARK: Constants

private extension BannersLocalizationFactory {
    enum Constants {
        static var localizationPath: String {
            #if F_RELEASE
                "localized"
            #else
                "localized_dev"
            #endif
        }
    }
}

enum BannersLocalizationFetchErrors: Error {
    case badURL
}
