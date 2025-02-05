import Foundation
import Operation_iOS

protocol BannersFetchOperationFactoryProtocol {
    func createOperation() -> BaseOperation<[Banner]?>
}

class BannersFetchOperationFactory {
    private let domain: Banners.Domain
    private let bannersContentPath: String
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol

    private var bannersProvider: AnySingleValueProvider<[Banner]>?

    init(
        domain: Banners.Domain,
        bannersContentPath: String,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    ) {
        self.domain = domain
        self.bannersContentPath = bannersContentPath
        self.jsonDataProviderFactory = jsonDataProviderFactory
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

// MARK: BannersFetchOperationFactoryProtocol

extension BannersFetchOperationFactory: BannersFetchOperationFactoryProtocol {
    func createOperation() -> BaseOperation<[Banner]?> {
        guard let url = createURL() else {
            return .createWithResult(nil)
        }

        let resultClosure: (
            (Result<[Banner]?, Error>)?,
            (Result<[Banner]?, Error>) -> Void
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
                let provider: AnySingleValueProvider<[Banner]>
                provider = jsonDataProviderFactory.getJson(for: url)

                bannersProvider = provider

                _ = provider.fetch { resultClosure($0, closure) }
            }
        }
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
