import UIKit

final class NftListInteractor {
    weak var presenter: NftListInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.nftLocalSubscriptionFactory = nftLocalSubscriptionFactory
    }
}

extension NftListInteractor: NftListInteractorInputProtocol {
    func setup() {

    }

    func refresh() {

    }
}
