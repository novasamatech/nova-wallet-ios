import Foundation

final class BranchDeepLinkInternalFactory {
    let scheme: String

    init(scheme: String) {
        self.scheme = scheme
    }
}

extension BranchDeepLinkInternalFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLinkParams) -> URL? {
        let optPath = externalParams[BranchParamKey.deepLinkPath] ??
            externalParams[BranchParamKey.iosDeepLinkPath]

        guard let path = optPath as? String else {
            return nil
        }

        return URL(string: scheme + "://" + path)
    }
}
