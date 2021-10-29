import Foundation
import FearlessUtils
import UIKit

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel
}

final class ChainAccountViewModelFactory {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }
}

extension ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel {
        /*
         let icon = try? iconGenerator.generateFromAddress(settings.details)
         let genericAddress = try wallet.substrateAccountId.toAddress(
             using: ChainFormat.substrate(42)
         )
         */
        let chains = chains.map { (_: ChainModel.Id, chain: ChainModel) in
            ChainAccountViewModelItem(
                name: chain.name,
                address: "123ouh1ieyglafqliuheoq134", // TODO: Generate icon
                warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
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
