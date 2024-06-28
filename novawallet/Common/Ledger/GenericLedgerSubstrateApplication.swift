import Foundation
import Operation_iOS

struct GenericLedgerSubstrateSigningParams {
    let extrinsicProof: Data
    let derivationPath: Data
}

protocol GenericLedgerSubstrateAccountProtocol {
    var connectionManager: LedgerConnectionManagerProtocol { get }

    func getAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse>
}

extension GenericLedgerSubstrateAccountProtocol {
    func getUniversalAccountWrapper(
        for deviceId: UUID,
        index: UInt32 = 0,
        displayVerificationDialog: Bool = false
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        getAccountWrapper(
            for: deviceId,
            index: index,
            addressPrefix: 42,
            displayVerificationDialog: displayVerificationDialog
        )
    }
}

typealias GenericLedgerSubstrateApplicationProtocol = GenericLedgerSubstrateAccountProtocol &
    NewSubstrateLedgerSigningProtocol

final class GenericLedgerSubstrateApplication: NewSubstrateLedgerApplication {}

extension GenericLedgerSubstrateApplication: GenericLedgerSubstrateApplicationProtocol {
    static let coin: UInt32 = 354

    func getAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        getAccountWrapper(
            for: deviceId,
            coin: Self.coin,
            index: index,
            addressPrefix: addressPrefix,
            displayVerificationDialog: displayVerificationDialog
        )
    }
}
