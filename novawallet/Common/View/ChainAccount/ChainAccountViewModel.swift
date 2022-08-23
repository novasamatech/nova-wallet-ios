import Foundation
import SubstrateSdk

struct ChainAccountViewModel {
    let networkName: String
    let networkIconViewModel: ImageViewModelProtocol?
    let displayAddressViewModel: StackCellViewModel?
}
