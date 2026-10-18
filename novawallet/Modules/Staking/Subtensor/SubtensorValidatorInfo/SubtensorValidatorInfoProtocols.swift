import Foundation

struct SubtensorValidatorInfoViewModel {
    struct Stake {
        let amount: String
        let price: String?
    }

    struct Staking {
        let status: String
        let isActive: Bool
        let stake: LoadableViewModelState<Stake>
        let take: String
        let reward: LoadableViewModelState<String>
        let rewardDetail: String?
        let hasReward: Bool
    }

    let coverage: LoadableViewModelState<String>
    let account: DisplayAddressViewModel
    let staking: Staking?
}

struct SubtensorValidatorInfoSnapshot {
    let annualRate: HTTPCachePeek<Decimal?>
    let alphaPrice: HTTPCachePeek<Balance?>
}

protocol SubtensorValidatorInfoViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: SubtensorValidatorInfoViewModel)
}

protocol SubtensorValidatorInfoPresenterProtocol: AnyObject {
    func setup()
    func presentAccountOptions()
    func showStakeInfo()
    func showTakeInfo()
}

protocol SubtensorValInfoInteractorInputProtocol: AnyObject {
    func cachedSnapshot() -> SubtensorValidatorInfoSnapshot
    func setup()
    func loadDetail()
}

protocol SubtensorValInfoInteractorOutputProtocol: AnyObject {
    func didReceive(coverage: SubtensorValidatorCoverage?)
    func didReceive(detail: SubtensorValidatorDirectoryItem)
    func didFailDetail(_ error: Error)
    func didReceive(annualRate: Decimal?)
    func didReceive(alphaPrice: Balance?)
    func didReceive(price: PriceData?)
}

protocol SubtensorValidatorInfoWireframeProtocol: SubtensorInfoSheetPresentable, AlertPresentable,
    CommonRetryable, AddressOptionsPresentable {
    func close(view: ControllerBackedProtocol?)
}
