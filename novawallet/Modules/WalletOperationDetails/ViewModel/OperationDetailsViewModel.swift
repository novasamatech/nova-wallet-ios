import Foundation

struct OperationDetailsViewModel {
    enum ContentViewModel {
        case transfer(_ viewModel: OperationTransferViewModel)
        case reward(_ viewModel: OperationRewardViewModel)
        case slash(_ viewModel: OperationSlashViewModel)
        case extrinsic(_ viewModel: OperationExtrinsicViewModel)
    }

    let time: String
    let status: OperationDetailsModel.Status
    let amount: String
    let networkViewModel: NetworkViewModel
    let iconViewModel: ImageViewModelProtocol?
    let content: ContentViewModel
}
