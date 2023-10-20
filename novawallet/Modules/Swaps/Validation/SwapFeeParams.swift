import BigInt

struct SwapFeeParams {
    let fee: BigUInt?
    let feeChainAsset: ChainAsset
    let feeAssetBalance: AssetBalance?
    let edAmount: BigUInt?
    let edAmountInFeeToken: BigUInt?
    let edChainAsset: ChainAsset
    let edChainAssetBalance: AssetBalance?
    let payChainAsset: ChainAsset
    let amountUpdateClosure: (Decimal) -> Void
}

extension SwapFeeParams {
    func prepare(swapAmount: Decimal?) -> SwapFeeResult {
        let params = self
        let fee = params.fee ?? 0
        let feeDecimal = Decimal.fromSubstrateAmount(
            fee,
            precision: Int16(params.feeChainAsset.asset.precision)
        ) ?? 0
        let feeTokenBalance = params.feeAssetBalance?.transferable ?? 0
        let feeTokenBalanceDecimal = Decimal.fromSubstrateAmount(
            feeTokenBalance,
            precision: Int16(params.feeChainAsset.asset.precision)
        ) ?? 0

        let edBalance = params.edAmount ?? 0
        let edDecimal = Decimal.fromSubstrateAmount(
            edBalance,
            precision: Int16(params.edChainAsset.asset.precision)
        ) ?? 0
        let edBalanceTransferrable = params.edChainAssetBalance?.transferable ?? 0
        let edBalanceTransferrableDecimal = Decimal.fromSubstrateAmount(
            edBalanceTransferrable,
            precision: Int16(params.edChainAsset.asset.precision)
        ) ?? 0
        let edDepositInFeeToken = params.edAmountInFeeToken ?? 0
        let edDepositInFeeTokenDecimal = Decimal.fromSubstrateAmount(
            edDepositInFeeToken,
            precision: Int16(params.feeChainAsset.asset.precision)
        ) ?? 0

        let toBuyED = params.edChainAsset != params.feeChainAsset && edBalanceTransferrableDecimal == 0 ? edDepositInFeeTokenDecimal : 0
        let swapAmount = swapAmount ?? 0
        let swapAmountInFeeToken = params.payChainAsset == params.feeChainAsset ? swapAmount : 0
        let needToPay = swapAmountInFeeToken + feeDecimal + toBuyED
        let diff = needToPay - feeTokenBalanceDecimal
        let availableToPay = feeTokenBalanceDecimal - diff

        return .init(
            availableToPay: availableToPay,
            feeDecimal: feeDecimal,
            toBuyED: toBuyED,
            edDepositInFeeTokenDecimal: edDepositInFeeTokenDecimal,
            diff: diff,
            edDecimal: edDecimal,
            feeTokenBalanceDecimal: feeTokenBalanceDecimal,
            swapAmountInFeeToken: swapAmountInFeeToken
        )
    }

    struct SwapFeeResult {
        let availableToPay: Decimal
        let feeDecimal: Decimal
        let toBuyED: Decimal
        let edDepositInFeeTokenDecimal: Decimal
        let diff: Decimal
        let edDecimal: Decimal
        let feeTokenBalanceDecimal: Decimal
        let swapAmountInFeeToken: Decimal
    }
}
