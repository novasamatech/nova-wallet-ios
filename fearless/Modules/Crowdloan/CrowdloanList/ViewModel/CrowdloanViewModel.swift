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
    let tokenSymbol: String
    let contributions: [CrowdloanContrubutionItem]
    let active: CrowdloansSectionViewModel<CrowdloanCellViewModel>?
    let completed: CrowdloansSectionViewModel<CrowdloanCellViewModel>?
}

struct CrowdloansSectionViewModel<T> {
    let title: String
    let crowdloans: [CrowdloanSectionItem<T>]
}

struct CrowdloanSectionItem<T> {
    let paraId: ParaId
    let content: T
}

typealias CrowdloanActiveSection = CrowdloanSectionItem<CrowdloanCellViewModel>
typealias CrowdloanCompletedSection = CrowdloanSectionItem<CrowdloanCellViewModel>

enum CrowdloanDescViewModel {
    case address(_ address: String)
    case text(_ text: String)
}

struct CrowdloanCellViewModel {
    let title: String
    let timeleft: String?
    let description: CrowdloanDescViewModel
    let progress: String
    let iconViewModel: ImageViewModelProtocol
    let contribution: String?
}
