import Foundation

struct LedgerAccount: LedgerDecodable {
    let address: AccountAddress
    let publicKey: Data

    init(ledgerData: Data) throws {
        let publicKeySize = 32
        publicKey = ledgerData.prefix(publicKeySize)

        guard publicKey.count == publicKeySize else {
            throw LedgerError.unexpectedData("No public key")
        }

        let accountAddressData = ledgerData.suffix(ledgerData.count - publicKey.count)

        guard
            let accountAddress = AccountAddress(data: accountAddressData, encoding: .ascii),
            (try? accountAddress.toAccountId()) != nil else {
            throw LedgerError.unexpectedData("Invalid account address")
        }

        address = accountAddress
    }
}
