import Foundation

final class BranchDeepLinkInternalFactory {
    let scheme: String

    init(scheme: String) {
        self.scheme = scheme
    }
}

extension BranchDeepLinkInternalFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLinkParams) -> URL? {
        let optPath = externalParams[BranchParamKey.deepLink] ?? externalParams[BranchParamKey.iosDeepLink]

        guard let path = optPath as? String else {
            return nil
        }

        var components = URLComponents(string: path)

        components?.scheme = scheme

        return components?.url
    }
}
