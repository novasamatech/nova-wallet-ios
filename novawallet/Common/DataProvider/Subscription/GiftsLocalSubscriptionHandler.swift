import Foundation
import Operation_iOS

protocol GiftsLocalSubscriptionHandler: AnyObject {
    func handleAllGifts(
        result: Result<[DataProviderChange<GiftModel>], Error>
    )
}

extension GiftsLocalSubscriptionHandler {
    func handleAllGifts(
        result _: Result<[DataProviderChange<GiftModel>], Error>
    ) {}
}
