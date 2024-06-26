import Foundation
import Operation_iOS

class NewSubstrateLedgerApplication: SubstrateLedgerCommonApplication {
    static let cla: UInt8 = 249

    func getAccountWrapper(
        for deviceId: UUID,
        coin: UInt32,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: coin, accountIndex: index)
            .build()

        return prepareAccountWrapper(
            for: deviceId,
            cla: Self.cla,
            derivationPath: path,
            payloadClosure: { Data(path.bytes + addressPrefix.littleEndianBytes) },
            displayVerificationDialog: displayVerificationDialog
        )
    }
}
