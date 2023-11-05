enum SwapDisplayError {
    struct InsufficientBalanceDueFeePayAsset {
        let available: String
        let fee: String
        let minBalanceInPayAsset: String
        let minBalanceInUtilityAsset: String
        let tokenSymbol: String
    }

    struct InsufficientBalanceDueFeeNativeAsset {
        let available: String
        let fee: String
    }

    enum InsufficientBalance {
        case dueFeePayAsset(InsufficientBalanceDueFeePayAsset)
        case dueFeeNativeAsset(InsufficientBalanceDueFeeNativeAsset)
    }

    struct DustRemainsDueNativeSwap {
        let remaining: String
        let minBalance: String
    }

    struct DustRemainsDueFeeSwap {
        let remaining: String
        let minBalanceOfPayAsset: String
        let fee: String
        let minBalanceInPayAsset: String
        let minBalanceInUtilityAsset: String
        let utilitySymbol: String
    }

    enum DustRemains {
        case dueNativeSwap(DustRemainsDueNativeSwap)
        case dueFeeSwap(DustRemainsDueFeeSwap)
    }
}
