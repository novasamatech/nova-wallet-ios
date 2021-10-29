import Foundation
import FearlessUtils
import UIKit

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModel(from chains: [ChainModel.Id: ChainModel]) -> ChainAccountListViewModel
}

final class ChainAccountViewModelFactory {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }
}

extension ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    func createViewModel(from chains: [ChainModel.Id: ChainModel]) -> ChainAccountListViewModel {
        let chains = chains.map { (_: ChainModel.Id, chain: ChainModel) in
            ChainAccountViewModelItem(
                name: chain.name,
                address: "123ouh1ieyglafqliuheoq134", // TODO: Generate icon
                chainIconViewModel: RemoteImageViewModel(url: chain.icon),
                accountIcon: nil // TODO: Generate icon
            )
        }

        return [ChainAccountListSectionViewModel(
            section: .sharedSecret,
            chainAccounts: chains
        )]
    }
}
