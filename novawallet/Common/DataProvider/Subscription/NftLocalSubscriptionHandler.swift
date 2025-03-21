import Foundation
import Operation_iOS

protocol NftLocalSubscriptionHandler: AnyObject {
    func handleNfts(result: Result<[DataProviderChange<NftModel>], Error>, wallet: MetaAccountModel)
}

extension NftLocalSubscriptionHandler {
    func handleNfts(result _: Result<[DataProviderChange<NftModel>], Error>, wallet _: MetaAccountModel) {}
}
