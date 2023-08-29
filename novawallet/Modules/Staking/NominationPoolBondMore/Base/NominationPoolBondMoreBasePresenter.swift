import Foundation
import BigInt
import SoraFoundation

class NominationPoolBondMoreBasePresenter: NominationPoolBondMoreBaseInteractorOutputProtocol {
    weak var view: NominationPoolBondMoreViewProtocol?
    let baseWireframe: NominationPoolBondMoreBaseWireframeProtocol
    let baseInteractor: NominationPoolBondMoreBaseInteractorInputProtocol

    let chainAsset: ChainAsset
    //  let hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var poolMember: NominationPools.PoolMember?
    var bondedPool: NominationPools.BondedPool?
    var stakingLedger: StakingLedger?
    var price: PriceData?
    var fee: BigUInt?

    init(
        interactor: NominationPoolBondMoreBaseInteractorInputProtocol,
        wireframe: NominationPoolBondMoreWireframeProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol

    ) {
        baseInteractor = interactor
        baseWireframe = wireframe
        self.logger = logger
        self.chainAsset = chainAsset
    }

    func updateView() {
        fatalError("Must be overriden by subsclass")
    }

    func provideHints() {
        fatalError("Must be overriden by subsclass")
    }

    func provideFee() {
        fatalError("Must be overriden by subsclass")
    }

    func getInputAmountInPlank() -> BigUInt? {
        fatalError("Must be overriden by subsclass")
    }

    func getStakedAmountInPlank() -> BigUInt? {
        guard
            let stakingLedger = stakingLedger,
            let bondedPool = bondedPool,
            let poolMember = poolMember else {
            return nil
        }

        return NominationPools.pointsToBalance(
            for: poolMember.points,
            totalPoints: bondedPool.points,
            poolBalance: stakingLedger.active
        )
    }

    func refreshFee() {
        guard
            let inputAmount = getInputAmountInPlank(),
            let stakingLedger = stakingLedger,
            let bondedPool = bondedPool else {
            return
        }

        fee = nil

        provideFee()

//        let points = NominationPools.balanceToPoints(
//            for: inputAmount,
//            totalPoints: bondedPool.points,
//            poolBalance: stakingLedger.active
//        )

        baseInteractor.estimateFee(for: 0)
    }

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        let shouldRefreshFee = poolMember?.points != self.poolMember?.points

        self.poolMember = poolMember
        provideHints()

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(bondedPool: NominationPools.BondedPool?) {
        let shouldRefreshFee = bondedPool?.points != self.bondedPool?.points

        self.bondedPool = bondedPool

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(stakingLedger: StakingLedger?) {
        let shouldRefreshFee = stakingLedger?.active != self.stakingLedger?.active

        self.stakingLedger = stakingLedger

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(price: PriceData?) {
        self.price = price
    }

    func didReceive(fee: BigUInt?) {
        self.fee = fee

        provideFee()
    }

    func didReceive(error _: NominationPoolBondMoreError) {}
}

extension NominationPoolBondMoreBasePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
