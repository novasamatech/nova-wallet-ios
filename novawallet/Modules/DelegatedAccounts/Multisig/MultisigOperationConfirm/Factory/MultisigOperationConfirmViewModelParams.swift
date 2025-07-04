import Foundation

struct MultisigOperationConfirmViewModelParams {
    let pendingOperation: Multisig.PendingOperationProxyModel
    let chain: ChainModel
    let multisigWallet: MetaAccountModel
    let signatories: [Multisig.Signatory]
    let fee: ExtrinsicFeeProtocol?
    let feeAsset: ChainAsset
    let assetPrice: PriceData?
    let confirmClosure: () -> Void
    let callDataAddClosure: () -> Void
}
