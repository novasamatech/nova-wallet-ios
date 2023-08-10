import UIKit
import RobinHood
import BigInt

final class StakingTypeInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingTypeInteractorOutputProtocol?
    let directStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let nominationPoolsRestrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let directStakingRecommendationMediator: RelaychainStakingRecommendationMediating
    let nominationPoolRecommendationMediator: RelaychainStakingRecommendationMediating
    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingSelectionMethod: StakingSelectionMethod
    let amount: BigUInt

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        amount: BigUInt,
        stakingSelectionMethod: StakingSelectionMethod,
        directStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        nominationPoolsRestrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        directStakingRecommendationMediator: RelaychainStakingRecommendationMediating,
        nominationPoolRecommendationMediator: RelaychainStakingRecommendationMediating
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.amount = amount
        self.stakingSelectionMethod = stakingSelectionMethod
        self.directStakingRestrictionsBuilder = directStakingRestrictionsBuilder
        self.nominationPoolsRestrictionsBuilder = nominationPoolsRestrictionsBuilder
        self.directStakingRecommendationMediator = directStakingRecommendationMediator
        self.nominationPoolRecommendationMediator = nominationPoolRecommendationMediator
    }

    deinit {
        directStakingRestrictionsBuilder.stop()
        nominationPoolsRestrictionsBuilder.stop()
        directStakingRecommendationMediator.stopRecommending()
        nominationPoolRecommendationMediator.stopRecommending()
    }

    private func provideDirectStakingRecommendation() {
        nominationPoolRecommendationMediator.delegate = nil
        nominationPoolRecommendationMediator.stopRecommending()

        directStakingRecommendationMediator.delegate = self
        directStakingRecommendationMediator.update(amount: amount)
        directStakingRecommendationMediator.startRecommending()
    }

    private func provideNominationPoolStakingRecommendation() {
        directStakingRecommendationMediator.delegate = nil
        directStakingRecommendationMediator.stopRecommending()

        nominationPoolRecommendationMediator.delegate = self
        nominationPoolRecommendationMediator.update(amount: amount)
        nominationPoolRecommendationMediator.startRecommending()
    }
}

extension StakingTypeInteractor: StakingTypeInteractorInputProtocol {
    func setup() {
        [
            directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder
        ].forEach {
            $0.delegate = self
            $0.start()
        }
    }

    func change(stakingTypeSelection: StakingTypeSelection) {
        switch stakingTypeSelection {
        case .direct:
            provideDirectStakingRecommendation()
        case .nominationPool:
            provideNominationPoolStakingRecommendation()
        }
    }
}

extension StakingTypeInteractor: RelaychainStakingRestrictionsBuilderDelegate {
    func restrictionsBuilder(
        _ builder: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    ) {
        if builder === directStakingRestrictionsBuilder {
            presenter?.didReceive(directStakingRestrictions: restrictions)
        } else if builder === nominationPoolsRestrictionsBuilder {
            presenter?.didReceive(nominationPoolRestrictions: restrictions)
        }
    }

    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didReceive error: Error
    ) {
        presenter?.didReceive(error: .restrictions(error))
    }
}

extension StakingTypeInteractor: RelaychainStakingRecommendationDelegate {
    func didReceive(
        recommendation: RelaychainStakingRecommendation,
        amount _: BigUInt
    ) {
        let model = RelaychainStakingManual(
            staking: recommendation.staking,
            restrictions: recommendation.restrictions,
            usedRecommendation: true
        )

        presenter?.didReceive(method: .manual(model))

        directStakingRecommendationMediator.stopRecommending()
        nominationPoolRecommendationMediator.stopRecommending()
    }

    func didReceiveRecommendation(error: Error) {
        presenter?.didReceive(error: .recommendation(error))
    }
}
