import Foundation

enum MercuryoCardResourceProviderError: Error {
    case unavailable
}

final class MercuryoCardResourceProvider {}

extension MercuryoCardResourceProvider: PayCardResourceProviding {
    func loadResource() throws -> PayCardHtmlResource {
        guard let htmlFile = R.file.mercuryoWidgetHtml() else {
            throw MercuryoCardResourceProviderError.unavailable
        }

        let htmlString = try String(contentsOf: htmlFile, encoding: .utf8)

        return PayCardHtmlResource(url: MercuryoCardApi.widgetUrl, content: htmlString)
    }
}
