import Foundation
import Foundation_iOS

struct CrowdloansViewModel {
    let sections: [CrowdloansSection]
}

enum CrowdloansSection {
    case yourContributions(LoadableViewModelState<YourContributionsView.Model>)
    case about(AboutCrowdloansView.Model)
    case active(LoadableViewModelState<String>, [LoadableViewModelState<CrowdloanCellViewModel>])
    case completed(LoadableViewModelState<String>, [LoadableViewModelState<CrowdloanCellViewModel>])
    case empty(title: String)

    var isLoading: Bool {
        switch self {
        case let .yourContributions(loadableViewModelState):
            return loadableViewModelState.isLoading
        case let .active(loadableViewModelState, array), let .completed(loadableViewModelState, array):
            if loadableViewModelState.isLoading {
                return true
            } else {
                let isLoading = array.contains { loadableState in
                    loadableState.isLoading
                }

                return isLoading
            }
        case .about, .error, .empty:
            return false
        }
    }
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
