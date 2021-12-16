import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk
import RobinHood
import SoraFoundation

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {
    let accountId: AccountId
    let chainFormat: ChainFormat
    let contactViewModelFactory: ContactsFactoryWrapperProtocol

    private lazy var addressFactory = SS58AddressFactory()

    init(
        accountId: AccountId,
        chainFormat: ChainFormat,
        contactViewModelFactory: ContactsFactoryWrapperProtocol
    ) {
        self.accountId = accountId
        self.chainFormat = chainFormat
        self.contactViewModelFactory = contactViewModelFactory
    }

    func search(
        query: String,
        parameters: ContactModuleParameters,
        locale: Locale,
        delegate: ContactViewModelDelegate?,
        commandFactory: WalletCommandFactoryProtocol
    ) -> [ContactViewModelProtocol]? {
        do {
            let peerId = try query.toAccountId(using: chainFormat)

            guard peerId != accountId else {
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
