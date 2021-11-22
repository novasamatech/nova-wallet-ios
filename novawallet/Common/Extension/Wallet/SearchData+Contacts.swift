import Foundation
import CommonWallet
import IrohaCrypto

extension SearchData {
    static func createFromContactItem(
        _ contactItem: ContactItem,
        networkType: SNAddressType,
        addressFactory: SS58AddressFactory
    ) throws -> SearchData {
        let accountId = try addressFactory.accountId(
            fromAddress: contactItem.peerAddress,
            type: networkType
        )

        let contactContext = ContactContext(destination: .remote)

        return SearchData(
            accountId: accountId.toHex(),
            firstName: contactItem.peerAddress,
            lastName: contactItem.peerName ?? "",
            context: contactContext.toContext()
        )
    }
}
