import XCTest
import BigInt
import Foundation_iOS
@testable import novawallet

final class StakingTypeTests: XCTestCase {
    // Pins the ValidatorSelectionSeeder.seed(...) call inside selectValidators(): a locked
    // validator absent from the manual targets (e.g. selected before the lock rule applied)
    // must still reach the validators screen.
    func testSelectValidatorsSeedsLockedValidatorIntoSelection() {
        // given

        let communityValidator = SelectedValidatorInfo(
            address: "community1",
            identity: AccountIdentity(name: "community1"),
            stakeInfo: ValidatorStakeInfo(totalStake: 10, stakeReturn: 0.5)
        )

        let lockedValidator = SelectedValidatorInfo(
            address: "nova1",
            identity: AccountIdentity(name: "nova1"),
            stakeInfo: ValidatorStakeInfo(totalStake: 10, stakeReturn: 0.1)
        )

        let electedAndPrefValidators = ElectedAndPrefValidators(
            allElectedValidators: [],
            notExcludedElectedValidators: [],
            preferredValidators: [lockedValidator]
        )

        let preparedValidators = PreparedValidators(
            targets: [communityValidator],
            maxTargets: 16,
            electedAndPrefValidators: electedAndPrefValidators,
            recommendedValidators: []
        )

        let restrictions = RelaychainStakingRestrictions(
            minJoinStake: nil,
            minRewardableStake: nil,
            allowsNewStakers: true
        )

        let method = StakingSelectionMethod.manual(
            RelaychainStakingManual(
                staking: .direct(preparedValidators),
                restrictions: restrictions,
                usedRecommendation: false
            )
        )

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )
        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let wireframe = StakingTypeWireframeStub()

        let presenter = StakingTypePresenter(
            interactor: StakingTypeInteractorInputStub(),
            wireframe: wireframe,
            chainAsset: chainAsset,
            amount: BigUInt(0),
            canChangeType: true,
            initialMethod: method,
            viewModelFactory: StakingTypeViewModelFactoryStub(),
            localizationManager: LocalizationManager.shared,
            delegate: nil
        )

        // when: the locked validator is not part of the manual targets, only of the lock set

        presenter.selectValidators()

        // then

        let seededAddresses = wireframe.capturedSelectedValidatorList?.items.map(\.address)

        XCTAssertEqual(seededAddresses, ["community1", "nova1"])
    }
}

// MARK: - Test doubles

private final class StakingTypeWireframeStub: StakingTypeWireframeProtocol {
    private(set) var capturedSelectedValidatorList: SharedList<SelectedValidatorInfo>?

    func complete(from _: ControllerBackedProtocol?) {}

    func showNominationPoolsList(
        from _: ControllerBackedProtocol?,
        amount _: BigUInt,
        delegate _: StakingSetupTypeEntityFacade,
        selectedPool _: NominationPools.SelectedPool?
    ) {}

    func showValidators(
        from _: ControllerBackedProtocol?,
        selectionValidatorGroups _: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams _: ValidatorsSelectionParams,
        delegate _: StakingSetupTypeEntityFacade
    ) {
        capturedSelectedValidatorList = selectedValidatorList
    }
}

private final class StakingTypeInteractorInputStub: StakingTypeInteractorInputProtocol {
    func setup() {}
    func change(stakingTypeSelection _: StakingTypeSelection) {}
}

private final class StakingTypeViewModelFactoryStub: StakingTypeViewModelFactoryProtocol {
    func directStakingViewModel(
        minStake _: BigUInt?,
        chainAsset _: ChainAsset,
        method _: StakingSelectionMethod?,
        locale _: Locale
    ) -> DirectStakingTypeViewModel {
        .init(title: "", subtile: "", validator: nil)
    }

    func nominationPoolViewModel(
        minStake _: BigUInt?,
        chainAsset _: ChainAsset,
        method _: StakingSelectionMethod?,
        canChangePool _: Bool,
        locale _: Locale
    ) -> PoolStakingTypeViewModel {
        .init(title: "", subtile: "", poolAccount: nil, canChangePool: true)
    }

    func minStake(minStake _: BigUInt?, chainAsset _: ChainAsset, locale _: Locale) -> String {
        ""
    }
}
