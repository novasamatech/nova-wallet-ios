import Foundation

class CrossChainDestinationSelectionState {
    let originChain: ChainModel
    let availableDestChains: [ChainModel]
    let selectedChainId: ChainModel.Id

    init(originChain: ChainModel, availableDestChains: [ChainModel], selectedChainId: ChainModel.Id) {
        self.originChain = originChain
        self.availableDestChains = availableDestChains
        self.selectedChainId = selectedChainId
    }
}
