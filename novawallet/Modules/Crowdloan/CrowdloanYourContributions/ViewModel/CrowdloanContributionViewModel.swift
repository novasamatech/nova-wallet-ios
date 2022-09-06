import Foundation

struct CrowdloanContributionViewModel {
    let index: Int
    let name: String
    let iconViewModel: ImageViewModelProtocol?
    let contributed: BalanceViewModelProtocol
}
