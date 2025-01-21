import Foundation
import BigInt

final class MythosStakingSetupPresenter {
    weak var view: CollatorStakingSetupViewProtocol?
    let wireframe: MythosStakingSetupWireframeProtocol
    let interactor: MythosStakingSetupInteractorInputProtocol
    let logger: LoggerProtocol

    init(
        interactor: MythosStakingSetupInteractorInputProtocol,
        wireframe: MythosStakingSetupWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }
}

extension MythosStakingSetupPresenter: CollatorStakingSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectCollator() {}
    func updateAmount(_: Decimal?) {}
    func selectAmountPercentage(_: Float) {}
    func proceed() {}
}

extension MythosStakingSetupPresenter: MythosStakingSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")
    }

    func didReceiveMinStakeAmount(_ amount: BigUInt) {
        logger.debug("Min stake: \(amount)")
    }

    func didReceiveMaxStakersPerCollator(_ maxStakersPerCollator: UInt32) {
        logger.debug("Max stakers per collator: \(maxStakersPerCollator)")
    }

    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32) {
        logger.debug("Max collators per staker: \(maxCollatorsPerStaker)")
    }

    func didReceiveDetails(_ details: MythosStakingDetails?) {
        logger.debug("Max collators per staker: \(String(describing: details))")
    }

    func didReceiveCandidateInfo(_ info: MythosStakingPallet.CandidateInfo?) {
        logger.debug("Candidate info: \(String(describing: info))")
    }

    func didReceivePreferredCollator(_ collator: DisplayAddress?) {
        logger.debug("Preferred Collator: \(String(describing: collator))")
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance) {
        logger.debug("Frozen Balance: \(frozenBalance)")
    }

    func didReceiveError(_ error: MythosStakingSetupError) {
        logger.debug("Error: \(error)")
    }
}
