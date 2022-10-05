import Foundation
import SoraFoundation
import CommonWallet

enum CrowdloanListState {
    case loading
    case loaded(viewModel: CrowdloansViewModel)
}

struct CrowdloansViewModel {
    let sections: [CrowdloansSection]
}

enum CrowdloansSection {
    case yourContributions(YourContributionsView.Model)
    case about(AboutCrowdloansView.Model)
    case active(String, [CrowdloanCellViewModel])
    case completed(String, [CrowdloanCellViewModel])
    case error(message: String)
    case empty(title: String)
}

enum CrowdloanDescViewModel {
    case address(_ address: String)
    case text(_ text: String)
}

struct CrowdloanCellViewModel {
    let paraId: ParaId
    let title: String
    let timeleft: String?
    let description: CrowdloanDescViewModel
    let progress: String
    let iconViewModel: ImageViewModelProtocol
    let progressPercentsText: String
    let progressValue: Double
    let isCompleted: Bool
}
