import Foundation
import SoraFoundation
import CommonWallet

struct CrowdloansViewModel {
    let sections: [CrowdloansSection]
}

enum CrowdloansSection {
    case yourContributions(LoadableViewModelState<YourContributionsView.Model>)
    case about(AboutCrowdloansView.Model)
    case active(String, [LoadableViewModelState<CrowdloanCellViewModel>])
    case completed(String, [LoadableViewModelState<CrowdloanCellViewModel>])
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
