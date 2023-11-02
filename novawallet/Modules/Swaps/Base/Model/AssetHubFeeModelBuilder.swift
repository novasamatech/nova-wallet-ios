import Foundation
typealias FeeChainAssetId = ChainAssetId

final class AssetHubFeeModelBuilder {
    typealias ResultClosure = (AssetConversion.FeeModel, AssetConversion.CallArgs, FeeChainAssetId?) -> Void
    let utilityChainAssetId: ChainAssetId
    let resultClosure: ResultClosure

    private(set) var feeAsset: ChainAsset?

    private var recepientUtilityBalance: AssetBalance?
    private var feeModel: AssetConversion.FeeModel?
    private var callArgs: AssetConversion.CallArgs?

    init(
        utilityChainAssetId: ChainAssetId,
        resultClosure: @escaping ResultClosure
    ) {
        self.utilityChainAssetId = utilityChainAssetId
        self.resultClosure = resultClosure
    }

    private func provideResult() {
        guard
            let balance = recepientUtilityBalance,
            let feeModel = feeModel,
            let callArgs = callArgs else {
            return
        }

        let resultModel: AssetConversion.FeeModel

        if balance.totalInPlank >= feeModel.totalFee.nativeAmount {
            // we have enough tokens for ed - need to exchange only network fee
            let networkFee = feeModel.networkFee
            resultModel = .init(totalFee: networkFee, networkFeeAddition: nil)
        } else {
            resultModel = feeModel
        }

        resultClosure(resultModel, callArgs, feeAsset?.chainAssetId)
    }
}

extension AssetHubFeeModelBuilder {
    func apply(recepientUtilityBalance: AssetBalance) {
        self.recepientUtilityBalance = recepientUtilityBalance
        provideResult()
    }

    func apply(feeModel: AssetConversion.FeeModel, args: AssetConversion.CallArgs) {
        self.feeModel = feeModel
        callArgs = args

        provideResult()
    }

    func apply(feeAsset: ChainAsset) {
        self.feeAsset = feeAsset
    }
}
