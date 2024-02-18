import Foundation
import RobinHood

protocol KodaDotNftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> CompoundOperationWrapper<KodaDotNftResponse>
    func fetchMetadata(for metadataId: String) -> CompoundOperationWrapper<KodaDotNftMetadataResponse>
    func fetchCollection(for collectionId: String) -> CompoundOperationWrapper<KodaDotNftCollectionResponse>
}

enum KodaDotApi {
    static let url = URL(string: "https://squid.subsquid.io/speck/graphql")!
}

final class KodaDotNftOperationFactory: SubqueryBaseOperationFactory {
    private func buildNftQuery(for address: AccountAddress) -> String {
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

    private func buildMetadataQuery(for metadataId: String) -> String {
        """
        {
            metadataEntityById(id: \"\(metadataId)\") {
                image
                name
                type
                description
            }
        }
        """
    }

    private func buildCollectionQuery(for collectionId: String) -> String {
        """
        {
            collectionEntityById(id: \"\(collectionId)\") {
                name
                image
                issuer
            }
        }
        """
    }
}

extension KodaDotNftOperationFactory: KodaDotNftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> CompoundOperationWrapper<KodaDotNftResponse> {
        let queryString = buildNftQuery(for: address)

        let operation: BaseOperation<KodaDotNftResponse> = createOperation(for: queryString)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchMetadata(for metadataId: String) -> CompoundOperationWrapper<KodaDotNftMetadataResponse> {
        let queryString = buildMetadataQuery(for: metadataId)

        let operation: BaseOperation<KodaDotNftMetadataResponse> = createOperation(for: queryString)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchCollection(for collectionId: String) -> CompoundOperationWrapper<KodaDotNftCollectionResponse> {
        let queryString = buildCollectionQuery(for: collectionId)

        let operation: BaseOperation<KodaDotNftCollectionResponse> = createOperation(for: queryString)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
