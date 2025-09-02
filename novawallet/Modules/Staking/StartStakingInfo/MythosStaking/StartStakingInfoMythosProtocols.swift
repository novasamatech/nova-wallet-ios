import Foundation

protocol StartStakingInfoMythosInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {}

protocol StartStakingInfoMythosInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(duration: MythosStakingDuration)
    func didReceive(minStake: Balance)
    func didReceive(currentSession: SessionIndex)
    func didReceive(blockNumber: BlockNumber?)
    func didReceive(calculator: CollatorStakingRewardCalculatorEngineProtocol)
}
