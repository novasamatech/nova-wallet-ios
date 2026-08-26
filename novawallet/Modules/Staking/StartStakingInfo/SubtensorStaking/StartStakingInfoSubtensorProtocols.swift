import Foundation

protocol StartStakingInfoSubtensorInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {}

protocol StartStakingInfoSubtensorInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(networkInfo: SubtensorNetworkInfo)
    func didReceive(rootAnnualReturn: Decimal?)
}

protocol StartStakingInfoSubtensorWireframeProtocol: StartStakingInfoWireframeProtocol,
    MessageSheetPresentable {}
