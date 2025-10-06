import Foundation

struct AHMFullInfo: Equatable {
    let info: AHMRemoteData
    let sourceChain: ChainModel
    let destinationChain: ChainModel
    let asset: AssetModel
}
