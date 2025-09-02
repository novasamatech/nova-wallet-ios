import Foundation

final class MythosStakingTransitionState: MythosStakingBaseState {
    private(set) var stakingDetailsState: MythosStakingDetailsState
    private(set) var frozenBalanceState: UncertainStorage<MythosStakingFrozenBalance?>

    init(
        stateMachine: MythosStakingStateMachineProtocol?,
        commonData: MythosStakingCommonData,
        stakingDetailsState: MythosStakingDetailsState = .undefined,
        frozenBalanceState: UncertainStorage<MythosStakingFrozenBalance?> = .undefined
    ) {
        self.stakingDetailsState = stakingDetailsState
        self.frozenBalanceState = frozenBalanceState

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: MythosStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    private func determineState() {
        guard
            case let .defined(optDetails) = stakingDetailsState,
            case let .defined(optFrozenBalance) = frozenBalanceState else {
            stateMachine?.transit(to: self)
            return
        }

        if
            let stakingDetails = optDetails,
            let frozenBalance = optFrozenBalance,
            frozenBalance.total > 0 {
            let delegatorState = MythosStakingDelegatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalance: frozenBalance,
                stakingDetails: stakingDetails
            )

            stateMachine?.transit(to: delegatorState)
        } else if let frozenBalance = optFrozenBalance, frozenBalance.total > 0 {
            let lockedState = MythosStakingLockedState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalance: frozenBalance
            )

            stateMachine?.transit(to: lockedState)
        } else if optDetails != nil {
            // looks like we didn't receive final frozen balance yet
            stateMachine?.transit(to: self)
        } else {
            let initState = MythosStakingInitState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine?.transit(to: initState)
        }
    }

    override func process(stakingDetailsState: MythosStakingDetailsState) {
        self.stakingDetailsState = stakingDetailsState

        determineState()
    }

    override func process(frozenBalance: MythosStakingFrozenBalance?) {
        frozenBalanceState = .defined(frozenBalance)

        determineState()
    }
}
