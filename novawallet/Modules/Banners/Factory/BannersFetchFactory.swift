import Foundation
import Operation_iOS

protocol BannersFetchOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<[Banner]?>
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
    func createWrapper() -> CompoundOperationWrapper<[Banner]?> {
        guard let url = createURL() else {
            return .createWithResult(nil)
        }

        if let bannersProvider {
            return bannersProvider.fetch(with: nil)
        } else {
            let provider: AnySingleValueProvider<[Banner]>
            provider = jsonDataProviderFactory.getJson(for: url)

            bannersProvider = provider

            return provider.fetch(with: nil)
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
