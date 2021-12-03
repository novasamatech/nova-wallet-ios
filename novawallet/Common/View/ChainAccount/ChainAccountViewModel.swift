import Foundation
import SubstrateSdk

struct ChainAccountViewModel {
    let networkName: String
    let address: String
    let accountIcon: DrawableIcon
    let networkIconViewModel: ImageViewModelProtocol?
}
