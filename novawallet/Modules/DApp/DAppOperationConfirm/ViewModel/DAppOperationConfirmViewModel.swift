import Foundation
import SubstrateSdk

struct DAppOperationConfirmViewModel {
    let iconImageViewModel: ImageViewModelProtocol?
    let dApp: String
    let walletName: String
    let walletIcon: DrawableIcon?
    let address: String
    let addressIcon: DrawableIcon?
    let networkName: String
    let networkIconViewModel: ImageViewModelProtocol?
}

enum DAppOperationFeeViewModel {
    case loading
    case empty
    case loaded(value: BalanceViewModelProtocol?)
}
