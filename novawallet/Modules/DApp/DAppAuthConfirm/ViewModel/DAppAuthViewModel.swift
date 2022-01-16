import Foundation
import SubstrateSdk

struct DAppAuthViewModel {
    let sourceImageViewModel: ImageViewModelProtocol?
    let destinationImageViewModel: ImageViewModelProtocol?
    let walletName: String
    let walletIcon: DrawableIcon?
    let dApp: String
    let origin: String?
}
