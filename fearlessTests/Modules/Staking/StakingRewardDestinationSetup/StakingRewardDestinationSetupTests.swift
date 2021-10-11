//
//  StakingRewardDestinationSetupTests.swift
//  fearlessTests
//
//  Created by Ruslan Rezin on 18.05.2021.
//  Copyright © 2021 Soramitsu. All rights reserved.
//

import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation
import BigInt

class StakingRewardDestinationSetupTests: XCTestCase {

    func testRewardDestinationSetupSuccess() throws {
        // given

        let view = MockStakingRewardDestSetupViewProtocol()
        let wireframe = MockStakingRewardDestSetupWireframeProtocol()

        let newPayoutAccount = AccountGenerator.generateMetaAccount()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe, newPayout: newPayoutAccount)

        let changesApplied = XCTestExpectation()

        // after changes from restake to payout and after account selection
        changesApplied.expectedFulfillmentCount = 2

        stub(view) { stub in
            when(stub).didReceiveRewardDestination(viewModel: any()).then { viewModel in
                if let viewModel = viewModel, viewModel.canApply {
                    changesApplied.fulfill()
                }
            }

            when(stub).localizationManager.get.then { nil }

            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
        }

        let payoutSelectionsExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).presentAccountSelection(
                any(),
                selectedAccountItem: any(),
                title: any(),
                delegate: any(),
                from: any(),
                context: any()
            ).then { (accounts, _, _, delegate, _, context) in
                if let index = accounts.firstIndex(
                    where: { newPayoutAccount.substrateAccountId == (try? $0.address.toAccountId()) }) {
                    delegate.modalPickerDidSelectModelAtIndex(index, context: context)

                    payoutSelectionsExpectation.fulfill()
                } else {
                    delegate.modalPickerDidCancel(context: context)
                }
            }

            when(stub).proceed(view: any(), rewardDestination: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.selectPayoutDestination()
        presenter.selectPayoutAccount()

        wait(for: [changesApplied, payoutSelectionsExpectation], timeout: 10.0)

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingRewardDestSetupViewProtocol,
        wireframe: MockStakingRewardDestSetupWireframeProtocol,
        newPayout: MetaAccountModel?
    ) throws -> StakingRewardDestSetupPresenter {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)
        let metaAccount = AccountGenerator.generateMetaAccount()
        let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest())!

        let operationManager = OperationManager()

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageTestFacade()
        )

        let accountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // save controller and payout
        let saveControllerOperation = accountRepository
            .saveOperation({
                if let payout = newPayout {
                    return [
                        ManagedMetaAccountModel(info: metaAccount, isSelected: true, order: 0),
                        ManagedMetaAccountModel(info: payout, isSelected: false, order: 1)
                    ]
                } else {
                    return [
                        ManagedMetaAccountModel(info: metaAccount, isSelected: true, order: 0)
                    ]
                }
            }, { [] })
        OperationQueue().addOperations([saveControllerOperation], waitUntilFinished: true)

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])
        let calculatorService = RewardCalculatorServiceStub(engine: WestendStub.rewardCalculator)

        let address = selectedAccount.toAddress()!
        let stashItem = StashItem(stash: address, controller: address)
        let ledgerInfo = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(2e+12),
            active: BigUInt(2e+12),
            unlocking: [],
            claimedRewards: []
        )

        let payee = RewardDestinationArg.staked

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: ledgerInfo,
            payee: payee,
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(balance: BigUInt(1e+14))

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: 0.1)
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: MultiassetCryptoType.sr25519)
        )

        let interactor = StakingRewardDestSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            calculatorService: calculatorService,
            runtimeService: chainRegistry.getRuntimeProvider(for: chain.chainId)!,
            operationManager: operationManager,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy()
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let viewModelFactory = ChangeRewardDestinationViewModelFactory(
            rewardDestinationViewModelFactory: rewardDestViewModelFactory
        )

        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: viewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            applicationConfig: ApplicationConfig.shared,
            assetInfo: assetInfo
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let rewardDestinationExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveFee(viewModel: any()).then { feeViewModel in
                if feeViewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceiveRewardDestination(viewModel: any()).then { viewModel in
                if let viewModel = viewModel, !viewModel.canApply {
                    rewardDestinationExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, rewardDestinationExpectation], timeout: 10)

        return presenter
    }

}
