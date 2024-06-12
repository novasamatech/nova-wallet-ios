import Foundation
import Operation_iOS

final class GovernanceDelegateMetadataFactory: BaseFetchOperationFactory {
    // swiftlint:disable:next line_length
    static let baseUrl = URL(string: "https://raw.githubusercontent.com/novasamatech/opengov-delegate-registry/master/registry/")!

    let timeout: TimeInterval

    init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

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
        return createFetchOperation(from: url, shouldUseCache: false, timeout: timeout)
    }
}
