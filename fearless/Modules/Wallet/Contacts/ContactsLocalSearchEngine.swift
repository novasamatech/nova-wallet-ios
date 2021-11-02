import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk
import RobinHood
import SoraFoundation

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {
    let metaAccount: MetaAccountModel
    let chains: [String: ChainModel]
    let contactViewModelFactory: ContactsFactoryWrapperProtocol

    private lazy var addressFactory = SS58AddressFactory()

    init(
        metaAccount: MetaAccountModel,
        chains: [String: ChainModel],
        contactViewModelFactory: ContactsFactoryWrapperProtocol
    ) {
        self.contactViewModelFactory = contactViewModelFactory
        self.metaAccount = metaAccount
        self.chains = chains
    }

    func search(
        query: String,
        parameters: ContactModuleParameters,
        locale: Locale,
        delegate: ContactViewModelDelegate?,
        commandFactory: WalletCommandFactoryProtocol
    ) -> [ContactViewModelProtocol]? {
        do {
            guard
                let chainAssetId = ChainAssetId(walletId: parameters.assetId),
                let chain = chains[chainAssetId.chainId] else {
                return []
            }

            let peerId = try query.toAccountId(using: chain.chainFormat)

            guard peerId != metaAccount.fetch(for: chain.accountRequest())?.accountId else {
                return []
            }

            let searchData = SearchData(
                accountId: peerId.toHex(),
                firstName: query,
                lastName: ""
            )

            guard let viewModel = contactViewModelFactory
                .createContactViewModelFromContact(
                    searchData,
                    parameters: parameters,
                    locale: locale,
                    delegate: delegate,
                    commandFactory: commandFactory
                )
            else {
                return nil
            }

            return [viewModel]
        } catch {
            return nil
        }
    }
}
