import Foundation

final class NftListViewModel {
    let identifier: NftModel.Id
    let metadataViewModel: NftListMetadataViewModelProtocol
    let price: BalanceViewModelProtocol?

    init(
        identifier: NftModel.Id,
        metadataViewModel: NftListMetadataViewModelProtocol,
        price: BalanceViewModelProtocol?
    ) {
        self.identifier = identifier
        self.metadataViewModel = metadataViewModel
        self.price = price
    }
}
