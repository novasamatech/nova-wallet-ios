import Foundation
import Operation_iOS

protocol Pdc20NftOperationFactoryProtocol {
    func fetchNfts(for address: String, network: String) -> CompoundOperationWrapper<Pdc20NftResponse>
}

enum Pdc20Api {
    static let url = URL(string: "https://squid.subsquid.io/dot-ordinals/graphql")!
    static let polkadotNetwork = "polkadot"
}

final class Pdc20NftOperationFactory: SubqueryBaseOperationFactory {
    private func buildQuery(for address: String, network: String) -> String {
        """
        {
           userTokenBalances(
             where: {
               address: {
                 address_eq: \"\(address)\"
               }
               standard_eq: \"pdc-20\"
               token: { network_eq: \"\(network)\" }
             }
           ) {
             balance
             address {
               address
             }
             token {
               id
               logo
               ticker
               totalSupply
               network
             }
           }

           listings(
             where: {
               from: { address_eq: \"\(address)\" }
               standard_eq: \"pdc-20\"
               token: { network_eq: \"\(network)\" }
             }
           ) {
             from {
               address
             }

             token {
               id
             }

             amount
             value
           }
        }
        """
    }
}

extension Pdc20NftOperationFactory: Pdc20NftOperationFactoryProtocol {
    func fetchNfts(for address: String, network: String) -> CompoundOperationWrapper<Pdc20NftResponse> {
        let queryString = buildQuery(for: address, network: network)

        let operation: BaseOperation<Pdc20NftResponse> = createOperation(for: queryString)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
