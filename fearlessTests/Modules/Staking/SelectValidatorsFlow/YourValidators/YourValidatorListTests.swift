import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import IrohaCrypto
import SoraFoundation
import BigInt

class YourValidatorListTests: XCTestCase {

    func testSetupCompletesAndActiveValidatorReceived() throws {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)
        let selectedMetaAccount = AccountGenerator.generateMetaAccount()
        let managedMetaAccount = ManagedMetaAccountModel(info: selectedMetaAccount)
        let selectedAccount = selectedMetaAccount.fetch(for: chain.accountRequest())!

        let operationManager = OperationManager()

        let nominatorAddress = selectedAccount.toAddress()!

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
        let accountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // save controller
        let operationQueue = OperationQueue()
        let saveControllerOperation = accountRepository.saveOperation({ [managedMetaAccount] }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress)
        let stakingLedger = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(16e+12),
            active: BigUInt(16e+12),
            unlocking: [],
            claimedRewards: []
        )

        let electedValidators: [EraValidatorInfo] = (0..<16).map { _ in
            let accountId = AccountGenerator.generateMetaAccount().substrateAccountId

            let nominator = IndividualExposure(who: selectedAccount.accountId, value: BigUInt(1e+12))

            let exposure = ValidatorExposure(
                total: BigUInt(2e+12),
                own: BigUInt(1e+12),
                others: [nominator]
            )

            return EraValidatorInfo(
                accountId: accountId,
                exposure: exposure,
                prefs: ValidatorPrefs(commission: BigUInt(1e+8), blocked: false)
            )
        }

        let activeValidators: [SelectedValidatorInfo] = try electedValidators.map { validator in
            let address = try validator.accountId.toAddress(using: chain.chainFormat)
            return SelectedValidatorInfo(address: address)
        }

        let expectedValidatorAddresses = Set(activeValidators.map { $0.address })

        let targets = electedValidators.map { $0.accountId }

        let nomination = Nomination(
            targets: targets,
            submittedIn: 1
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            nomination: nomination,
            ledgerInfo: stakingLedger,
            activeEra: ActiveEraInfo(index: 5),
            stashItem: stashItem
        )

        let validatorOperationFactory = MockValidatorOperationFactoryProtocol()

        stub(validatorOperationFactory) { stub in
            when(stub).allSelectedOperation(by: any(), nominatorAddress: any()).then { _ in
                CompoundOperationWrapper.createWithResult(activeValidators)
            }

            when(stub).pendingValidatorsOperation(for: any()).then { _ in
                CompoundOperationWrapper.createWithResult([])
            }

            when(stub).activeValidatorsOperation(for: any()).then { _ in
                CompoundOperationWrapper.createWithResult(activeValidators)
            }
        }

        let eraStakersInfo = EraStakersInfo(activeEra: 5, validators: electedValidators)
        let eraValidatorService = EraValidatorServiceStub(info: eraStakersInfo)

        let interactor = YourValidatorListInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            eraValidatorService: eraValidatorService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: operationManager
        )

        let chainInfo = chainAsset.chainAssetInfo

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainInfo.asset)

        let viewModelFactory = YourValidatorListViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory
        )

        let view = MockYourValidatorListViewProtocol()
        let wireframe = MockYourValidatorListWireframeProtocol()

        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainInfo: chainInfo,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view

        let expectation = XCTestExpectation()

        var receivedValidatorAddresses: Set<AccountAddress>?

        stub(view) { stub in
            when(stub).reload(state: any()).then { state in
                if case .validatorList(let viewModel) = state, !viewModel.sections.isEmpty {
                    receivedValidatorAddresses = viewModel.sections
                        .flatMap { $0.validators }
                        .reduce(into: Set<AccountAddress>()) { $0.insert($1.address) }
                    expectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(expectedValidatorAddresses, receivedValidatorAddresses)
    }
}
