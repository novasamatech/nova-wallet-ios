import Foundation
import SoraFoundation
import CommonWallet

enum CrowdloanListState {
    case loading
    case loaded(viewModel: CrowdloansViewModel)
    case error(message: String)
    case empty
}

struct CrowdloansViewModel {
    let sections: [CrowdloansSection]
}

enum CrowdloansSection {
    case yourContributions(String, Int)
    case active(String, [CrowdloanCellViewModel])
    case completed(String, [CrowdloanCellViewModel])
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
}
