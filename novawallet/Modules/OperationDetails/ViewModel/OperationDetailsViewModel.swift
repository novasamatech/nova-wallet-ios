import Foundation

struct OperationDetailsViewModel {
    enum ContentViewModel {
        case transfer(_ viewModel: OperationTransferViewModel)
        case reward(_ viewModel: OperationRewardViewModel)
        case slash(_ viewModel: OperationSlashViewModel)
        case extrinsic(_ viewModel: OperationExtrinsicViewModel)
        case contract(_ viewModel: OperationContractCallViewModel)
    }

    let time: String
    let status: OperationDetailsModel.Status
    let amount: BalanceViewModelProtocol?
    let networkViewModel: NetworkViewModel
    let iconViewModel: ImageViewModelProtocol?
    let content: ContentViewModel
}
