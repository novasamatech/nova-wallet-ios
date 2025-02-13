import Foundation
import Operation_iOS

protocol BannersLocalizationFactoryProtocol {
    func createOperation(for locale: Locale) -> BaseOperation<BannersLocalizedResources>
}

class BannersLocalizationFactory {
    private let domain: Banners.Domain
    private let bannersContentPath: String
    private let fetchOperationFactory: BaseFetchOperationFactory

    private var localizationProvider: AnySingleValueProvider<BannersLocalizedResources>?

    init(
        domain: Banners.Domain,
        bannersContentPath: String,
        fetchOperationFactory: BaseFetchOperationFactory
    ) {
        self.domain = domain
        self.bannersContentPath = bannersContentPath
        self.fetchOperationFactory = fetchOperationFactory
    }

    private func createLocalizationURL(for locale: Locale) -> URL? {
        guard let languageCode = locale.languageCode else { return nil }

        let domainValue = domain.rawValue

        let urlString = bannersContentPath + String(
            format: Constants.localizationPathFormat,
            domainValue,
            languageCode
        )

        return URL(string: urlString)
    }
}

// MARK: BannersLocalizationFactoryProtocol

extension BannersLocalizationFactory: BannersLocalizationFactoryProtocol {
    func createOperation(for locale: Locale) -> BaseOperation<BannersLocalizedResources> {
        guard let url = createLocalizationURL(for: locale) else {
            return .createWithError(BannersLocalizationFetchErrors.badURL)
        }

        return fetchOperationFactory.createFetchOperation(from: url)
    }
}

// MARK: Constants

private extension BannersLocalizationFactory {
    enum Constants {
        static let localizationPathFormat: String = "%@/localized/%@.json"
    }
}

enum BannersLocalizationFetchErrors: Error {
    case badURL
}
