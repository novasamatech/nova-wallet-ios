import Foundation
import Operation_iOS

protocol GenericLedgerSubstrateApplicationProtocol {
    var displayName: String { get }

    var connectionManager: LedgerConnectionManagerProtocol { get }

    func getAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse>
}

extension GenericLedgerSubstrateApplicationProtocol {
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

final class GenericLedgerSubstrateApplication: NewSubstrateLedgerApplication {}

extension GenericLedgerSubstrateApplication: GenericLedgerSubstrateApplicationProtocol {
    static let coin: UInt32 = 354

    var displayName: String { "Generic" }

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
