import Foundation

struct MultisigOperationConfirmViewModelParams {
    let pendingOperation: Multisig.PendingOperationProxyModel
    let chain: ChainModel
    let multisigWallet: MetaAccountModel
    let signatories: [Multisig.Signatory]
    let fee: ExtrinsicFeeProtocol?
    let chainAsset: ChainAsset
    let utilityAssetPrice: PriceData?
    let operationAssetPrice: PriceData?
    let confirmClosure: () -> Void
    let callDataAddClosure: () -> Void
}
