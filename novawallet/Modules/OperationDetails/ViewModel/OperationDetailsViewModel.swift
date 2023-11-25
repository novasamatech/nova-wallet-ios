import Foundation

struct OperationDetailsViewModel {
    enum ContentViewModel {
        case transfer(_ viewModel: OperationTransferViewModel)
        case reward(_ viewModel: OperationRewardOrSlashViewModel)
        case slash(_ viewModel: OperationRewardOrSlashViewModel)
        case extrinsic(_ viewModel: OperationExtrinsicViewModel)
        case contract(_ viewModel: OperationContractCallViewModel)
        case poolReward(_ viewModel: OperationPoolRewardOrSlashViewModel)
        case poolSlash(_ viewModel: OperationPoolRewardOrSlashViewModel)
        case swap(_ viewModel: OperationSwapViewModel)
    }

    let time: String
    let status: OperationDetailsModel.Status
    let amount: BalanceViewModelProtocol?
    let networkViewModel: NetworkViewModel
    let iconViewModel: ImageViewModelProtocol?
    let content: ContentViewModel
}
