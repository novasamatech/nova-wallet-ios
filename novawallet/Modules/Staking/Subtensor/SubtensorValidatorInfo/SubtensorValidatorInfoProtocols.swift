import Foundation

struct SubtensorValidatorInfoViewModel {
    struct Stake {
        let amount: String
        let price: String?
    }

    struct Staking {
        let status: String
        let isActive: Bool
        let stakeTitle: String
        let stake: LoadableViewModelState<Stake>
        let take: String
        let reward: LoadableViewModelState<String>
        let hasReward: Bool
    }

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
    func showStakeInfo()
    func showTakeInfo()
}

protocol SubtensorValInfoInteractorInputProtocol: AnyObject {
    func cachedSnapshot() -> SubtensorValidatorInfoSnapshot
    func setup()
    func loadDetail()
}

protocol SubtensorValInfoInteractorOutputProtocol: AnyObject {
    func didReceive(detail: SubtensorValidatorDetail)
    func didFailDetail(_ error: Error)
    func didReceive(annualRate: Decimal?)
    func didReceive(alphaPrice: Balance?)
    func didReceive(price: PriceData?)
}

protocol SubtensorValidatorInfoWireframeProtocol: SubtensorInfoSheetPresentable, AlertPresentable,
    CommonRetryable {
    func close(view: ControllerBackedProtocol?)
}
