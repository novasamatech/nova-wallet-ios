import Foundation

protocol BranchDeepLinkFactoryProtocol {
    func createDeepLink(from branchParams: ExternalUniversalLinkParams) -> URL?
}

final class BranchDeepLinkFactory {
    let children: [InternalLinkFactoryProtocol]

    init(config: ApplicationConfigProtocol) {
        let baseUrl = config.deepLinkURL

        children = [
            BranchDeepLinkInternalFactory(scheme: config.deepLinkScheme),
            BranchToDeepLinkConversionFactory(baseUrl: baseUrl)
        ]
    }
}

extension BranchDeepLinkFactory: BranchDeepLinkFactoryProtocol {
    func createDeepLink(from branchParams: ExternalUniversalLinkParams) -> URL? {
        for child in children {
            if let url = child.createInternalLink(from: branchParams) {
                return url
            }
        }

        return nil
    }
}
