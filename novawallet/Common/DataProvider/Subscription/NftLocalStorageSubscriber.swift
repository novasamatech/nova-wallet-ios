import Foundation
import RobinHood

protocol NftLocalStorageSubscriber: AnyObject {
    var nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol { get }

    var nftLocalSubscriptionHandler: WalletLocalSubscriptionHandler { get }

    func subscribeToNftProvider(
        for wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> StreamableProvider<NftModel>?
}
