import Foundation

protocol BranchDeepLinkFactoryProtocol {
    func createDeepLink(from branchParams: ExternalUniversalLink.Params) -> URL?
}

final class BranchDeepLinkFactory {
    let children: [InternalLinkFactoryProtocol]

    init(config: ApplicationConfigProtocol) {
        let baseUrl = config.deepLinkURL

        children = [
            BranchDeepLinkInternalFactory(scheme: config.deepLinkScheme),
            MnemonicInternalLinkFactory(baseUrl: baseUrl),
            StakingInternalLinkFactory(baseUrl: baseUrl),
            GovernanceInternalLinkFactory(baseUrl: baseUrl),
            DAppInternalLinkFactory(baseUrl: baseUrl)
        ]
    }
}

extension BranchDeepLinkFactory: BranchDeepLinkFactoryProtocol {
    func createDeepLink(from branchParams: ExternalUniversalLink.Params) -> URL? {
        for child in children {
            if let url = child.createInternalLink(from: branchParams) {
                return url
            }
        }

        return nil
    }
}
