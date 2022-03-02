import Foundation
import RobinHood

final class NftListViewModel {
    let identifier: NftModel.Id
    let metadataViewModel: NftListMetadataViewModelProtocol
    let price: BalanceViewModelProtocol?
    let createdAt: Date

    init(
        identifier: NftModel.Id,
        metadataViewModel: NftListMetadataViewModelProtocol,
        price: BalanceViewModelProtocol?,
        createdAt: Date
    ) {
        self.identifier = identifier
        self.metadataViewModel = metadataViewModel
        self.price = price
        self.createdAt = createdAt
    }
}

extension NftListViewModel: Identifiable {}
