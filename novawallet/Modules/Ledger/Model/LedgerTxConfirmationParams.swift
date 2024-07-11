import Foundation
import SubstrateSdk

struct LedgerTxConfirmationParams {
    let walletType: LedgerWalletType
    let extrinsicMemo: ExtrinsicBuilderMemoProtocol
    let codingFactory: RuntimeCoderFactoryProtocol
}
