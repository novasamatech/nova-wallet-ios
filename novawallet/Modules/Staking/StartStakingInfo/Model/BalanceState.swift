enum BalanceState {
    case assetBalance(AssetBalance)
    case noAccount
}

enum RewardsDestination {
    case balance
    case stake
}
