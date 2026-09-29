import Foundation

struct SubtensorPositionViewModel {
    let title: String
    let amount: String
    let fiat: String?
    let rewardTitle: String
    let rewardValue: String?
    let worthNow: String?
    let validator: String
    let isRoot: Bool
    let canOperate: Bool
    let hasRootHold: Bool
}

protocol SubtensorPositionViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorPositionViewModel)
    func didReceive(history: SubtensorPriceHistoryResult?)
}

protocol SubtensorPositionPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(_ period: SubtensorPricePeriod)
    func stakeMore()
    func unstake()
    func showValidatorInfo()
}

protocol SubtensorPositionInteractorInputProtocol: AnyObject {
    func setup()
    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod)
}

protocol SubnetPositionInteractorOutputProtocol: AnyObject {
    func didReceive(group: SubtensorPortfolioGroup)
    func didReceive(history: SubtensorPriceHistoryResult)
    func didReceive(subnetsInfo: SubtensorSubnetsInfo)
    func didReceive(price: PriceData?)
    func didReceive(claimable: SubtensorRootClaimable?)
    func didReceive(delegates: [SubtensorDelegate])
}

protocol SubtensorPositionWireframeProtocol: AnyObject {
    func showStake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition?)
    func showUnstake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition?)
    func showValidatorInfo(from view: SubtensorPositionViewProtocol?, delegate: SubtensorDelegate)
}
