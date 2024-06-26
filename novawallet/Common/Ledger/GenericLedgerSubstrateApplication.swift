import Foundation
import Operation_iOS

protocol GenericLedgerSubstrateApplicationProtocol {
    func getAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse>
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
