enum SwapDisplayError {
    struct InsufficientBalanceDueFeePayAsset {
        let available: String
        let fee: String
    }

    struct InsufficientBalanceDueFeeNativeAsset {
        let available: String
        let fee: String
    }

    struct InsufficientBalanceDueConsumers {
        let minBalance: String
        let fee: String
    }

    enum InsufficientBalance {
        case dueFeePayAsset(InsufficientBalanceDueFeePayAsset)
        case dueFeeNativeAsset(InsufficientBalanceDueFeeNativeAsset)
        case dueConsumers(InsufficientBalanceDueConsumers)
    }

    struct DustRemainsDueSwap {
        let remaining: String
        let minBalance: String
    }

    enum DustRemains {
        case dueSwap(DustRemainsDueSwap)
    }
}
