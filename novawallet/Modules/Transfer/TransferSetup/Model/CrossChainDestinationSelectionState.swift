import Foundation

class CrossChainDestinationSelectionState {
    let chain: ChainModel
    let availablePeerChains: [ChainModel]
    let selectedChainId: ChainModel.Id

    init(chain: ChainModel, availablePeerChains: [ChainModel], selectedChainId: ChainModel.Id) {
        self.chain = chain
        self.availablePeerChains = availablePeerChains
        self.selectedChainId = selectedChainId
    }
}
