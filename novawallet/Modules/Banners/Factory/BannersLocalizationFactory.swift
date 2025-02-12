import Foundation
import Operation_iOS

protocol BannersLocalizationFactoryProtocol {
    func createOperation(for locale: Locale) -> BaseOperation<BannersLocalizedResources?>
}

class BannersLocalizationFactory {
    private let domain: Banners.Domain
    private let bannersContentPath: String
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol

    private var localizationProvider: AnySingleValueProvider<BannersLocalizedResources>?

    init(
        domain: Banners.Domain,
        bannersContentPath: String,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    ) {
        self.domain = domain
        self.bannersContentPath = bannersContentPath
        self.jsonDataProviderFactory = jsonDataProviderFactory
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
    func createOperation(for locale: Locale) -> BaseOperation<BannersLocalizedResources?> {
        guard let url = createLocalizationURL(for: locale) else {
            return .createWithResult(nil)
        }

        let provider: AnySingleValueProvider<BannersLocalizedResources>
        provider = jsonDataProviderFactory.getJson(for: url)

        localizationProvider = provider

        return AsyncClosureOperation { closure in
            _ = provider.fetch { result in
                guard let result else {
                    closure(.failure(BannersLocalizationFetchErrors.localizablesListFetchError))
                    return
                }

                closure(result)
            }
        }
    }
}

// MARK: Constants

private extension BannersLocalizationFactory {
    enum Constants {
        static let localizationPathFormat: String = "%@/localized/%@.json"
    }
}

enum BannersLocalizationFetchErrors: Error {
    case localizablesListFetchError
}
