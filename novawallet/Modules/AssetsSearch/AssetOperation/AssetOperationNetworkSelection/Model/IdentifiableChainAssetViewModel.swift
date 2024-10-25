import Operation_iOS

struct IdentifiableChainAssetViewModel: Identifiable {
    var identifier: String {
        chainAssetId.stringValue
    }

    let chainAssetId: ChainAssetId
    let viewModel: ChainAssetViewModel
}
