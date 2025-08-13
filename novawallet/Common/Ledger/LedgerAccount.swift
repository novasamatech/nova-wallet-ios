import Foundation
import SubstrateSdk

protocol LedgerAccountProtocol: LedgerDecodable {
    var address: AccountAddress { get }
    var publicKey: Data { get }
}

struct LedgerSubstrateAccount: LedgerAccountProtocol {
    static let publicKeySize = 32

    let address: AccountAddress
    let publicKey: Data

    init(ledgerData: Data) throws {
        publicKey = ledgerData.prefix(Self.publicKeySize)

        guard publicKey.count == Self.publicKeySize else {
            throw LedgerError.unexpectedData("No substrate public key")
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

struct LedgerEvmAccount: LedgerAccountProtocol, LedgerDecodable {
    static let publicKeySize = 33

    let address: AccountAddress
    let publicKey: Data

    init(ledgerData: Data) throws {
        publicKey = ledgerData.prefix(Self.publicKeySize)

        guard publicKey.count == Self.publicKeySize else {
            throw LedgerError.unexpectedData("No evm public key")
        }

        address = try publicKey.ethereumAddressFromPublicKey().toAddress(using: .ethereum)
    }
}

struct LedgerAccountResponse<A: LedgerAccountProtocol> {
    let account: A
    let derivationPath: Data
}

typealias LedgerSubstrateAccountResponse = LedgerAccountResponse<LedgerSubstrateAccount>
typealias LedgerEvmAccountResponse = LedgerAccountResponse<LedgerEvmAccount>
