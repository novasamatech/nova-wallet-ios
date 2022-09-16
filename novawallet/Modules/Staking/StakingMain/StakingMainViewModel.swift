import Foundation
import SoraFoundation

struct StakingMainViewModel {
    let walletIdenticon: Data?
    let walletType: WalletsListSectionViewModel.SectionType
    let chainName: String
    let assetName: String
    let assetIcon: ImageViewModelProtocol?
    let balanceViewModel: LocalizableResource<String>?
}
