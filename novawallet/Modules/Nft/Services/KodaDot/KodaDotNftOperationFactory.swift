import Foundation
import Operation_iOS

protocol KodaDotNftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> CompoundOperationWrapper<KodaDotNftResponse>
    func fetchMetadata(for metadataId: String) -> CompoundOperationWrapper<KodaDotNftMetadataResponse>
    func fetchCollection(for collectionId: String) -> CompoundOperationWrapper<KodaDotNftCollectionResponse>
}

enum KodaDotAssetHubApi {
    static let polkadotAssetHub = URL(string: "https://ahp.gql.api.kodadot.xyz")!
    static let kusamaAssetHub = URL(string: "https://ahk.gql.api.kodadot.xyz")

    static func apiForChain(_ chainId: ChainModel.Id) -> URL? {
        switch chainId {
        case KnowChainId.kusamaAssetHub:
            return KodaDotAssetHubApi.kusamaAssetHub
        case KnowChainId.polkadotAssetHub:
            return KodaDotAssetHubApi.polkadotAssetHub
        default:
            return nil
        }
    }
}

final class KodaDotNftOperationFactory: SubqueryBaseOperationFactory {
    private func buildNftQuery(for _: AccountAddress) -> String {
        """
        query nftListByOwner($id: String!) {
           nftEntities(where: {currentOwner_eq: $id, burned_eq: false}) {
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
        let variables = ["id": address]

        let operation: BaseOperation<KodaDotNftResponse> = createOperation(
            for: queryString,
            variables: variables
        )

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
