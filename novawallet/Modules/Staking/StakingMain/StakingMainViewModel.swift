import Foundation
import SoraFoundation

struct StakingMainViewModel {
    let accountId: AccountId
    let chainName: String
    let assetName: String
    let assetIcon: ImageViewModelProtocol?
    let balanceViewModel: LocalizableResource<String>?
}
