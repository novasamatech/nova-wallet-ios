import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanLocalSearchEngine: InvoiceLocalSearchEngineProtocol {
    let chainFormat: ChainFormat

    private lazy var addressFactory = SS58AddressFactory()

    init(chainFormat: ChainFormat) {
        self.chainFormat = chainFormat
    }

    func searchByAccountId(_ accountIdHex: String) -> SearchData? {
        guard let accountId = AccountId.matchHex(accountIdHex) else {
            return nil
        }

        guard let address = try? accountId.toAddress(using: chainFormat) else {
            return nil
        }

        let context = ContactContext(destination: .local)
        return SearchData(
            accountId: accountIdHex,
            firstName: address,
            lastName: "",
            context: context.toContext()
        )
    }
}
