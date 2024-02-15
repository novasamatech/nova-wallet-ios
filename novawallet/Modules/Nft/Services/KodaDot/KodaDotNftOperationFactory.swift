import Foundation
import RobinHood

protocol KodaDotNftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> CompoundOperationWrapper<KodaDotNftResponse>
}

enum KodaDotApi {
    static let url = URL(string: "https://squid.subsquid.io/speck/graphql")!
}

final class KodaDotNftOperationFactory: SubqueryBaseOperationFactory {
    // swiftlint:disable:next function_body_length
    private func buildQuery(for address: AccountAddress) -> String {
        """
        {
           nftEntities(where: {currentOwner_eq: "\(address)"}) {
               id
               image
               metadata
               name
               price
               sn
               currentOwner
               collection {
                 id
                 max
                }
            }
        }
        """
    }
}

extension KodaDotNftOperationFactory: KodaDotNftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> CompoundOperationWrapper<KodaDotNftResponse> {
        let queryString = buildQuery(for: address)

        let operation: BaseOperation<KodaDotNftResponse> = createOperation(for: queryString)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
