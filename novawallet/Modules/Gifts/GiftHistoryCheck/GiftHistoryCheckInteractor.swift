import UIKit
import Operation_iOS

final class GiftHistoryCheckInteractor {
    weak var presenter: GiftHistoryCheckInteractorOutputProtocol?
    
    let giftsSubscriptionFactory:
    
    private var giftsProvider: StreamableProvider<GiftModel>?
}

extension GiftHistoryCheckInteractor: GiftHistoryCheckInteractorInputProtocol {}
