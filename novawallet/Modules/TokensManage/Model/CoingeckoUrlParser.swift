import Foundation

protocol PriceUrlParserProtocol {
    func parsePriceId(from urlString: String) -> AssetModel.PriceId?
}

final class CoingeckoUrlParser {
    static let host = "coingecko.com"

    private func isHostValid(_ host: String?) -> Bool {
        host == Self.host || host == ("www." + Self.host)
    }

    private func getPriceId(from path: String) -> String? {
        let paths = path
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }

        return paths.last
    }
}

extension CoingeckoUrlParser: PriceUrlParserProtocol {
    func parsePriceId(from urlString: String) -> AssetModel.PriceId? {
        guard
            let components = URLComponents(string: urlString),
            isHostValid(components.host)
        else {
            return nil
        }

        return getPriceId(from: components.path)
    }
}
