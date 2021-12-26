import Foundation
import SubstrateSdk

struct DAppOperationConfirmViewModel {
    let iconImageViewModel: ImageViewModelProtocol?
    let walletName: String
    let walletIcon: DrawableIcon?
    let address: String
    let addressIcon: DrawableIcon?
    let networkName: String
    let networkIconViewModel: ImageViewModelProtocol?
}
