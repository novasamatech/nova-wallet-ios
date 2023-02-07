import Foundation
import RobinHood

final class GovernanceDelegateMetadataFactory: BaseFetchOperationFactory {
    // swiftlint:disable:next line_length
    static let baseUrl = URL(string: "https://raw.githubusercontent.com/nova-wallet/opengov-delegate-registry/master/registry/")!

    func createUrl(for chain: ChainModel) -> URL {
        let normalizedName = chain.name.lowercased()

        return Self.baseUrl
            .appendingPathComponent(normalizedName)
            .appendingPathExtension("json")
    }
}

extension GovernanceDelegateMetadataFactory: GovernanceDelegateMetadataFactoryProtocol {
    func fetchMetadataOperation(for chain: ChainModel) -> BaseOperation<[GovernanceDelegateMetadataRemote]> {
        let url = createUrl(for: chain)
        return createFetchOperation(from: url)
    }
}
