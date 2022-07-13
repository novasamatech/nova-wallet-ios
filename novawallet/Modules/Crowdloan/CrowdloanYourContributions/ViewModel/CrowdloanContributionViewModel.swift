import Foundation

struct CrowdloanContributionViewModel {
    let name: String
    let iconViewModel: ImageViewModelProtocol?
    let contributed: BalanceViewModelProtocol
    let returnsIn: TimeInterval
}
