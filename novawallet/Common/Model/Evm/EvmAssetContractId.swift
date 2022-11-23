import Foundation

struct EvmAssetContractId: Equatable, Hashable {
    let chainAssetId: ChainAssetId
    let contract: AccountAddress
}
