import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
import CommonWallet
import IrohaCrypto
@testable import novawallet

class StakingBondMoreTests: XCTestCase {

    func testContinueAction() throws {
        let wireframe = MockStakingBondMoreWireframeProtocol()
        let interactor = MockStakingBondMoreInteractorInputProtocol()
        let balanceViewModelFactory = StubBalanceViewModelFactory()
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let assetInfo = chain.assets.first!.displayInfo

        let dataValidator = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidator,
            assetInfo: assetInfo
        )

        let view = MockStakingBondMoreViewProtocol()
        presenter.view = view
        dataValidator.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { _ in nil }
            when(stub).didReceiveInput(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
        }

        // given
        let continueExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any(), amount: any()).then { _ in
                continueExpectation.fulfill()
            }
        }

        // balance & fee is received
        let accountInfo = AccountInfo(
            nonce: 0,
            data: AccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )

        presenter.didReceiveAccountInfo(result: .success(accountInfo))

        let paymentInfo = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(paymentInfo))

        let stashItem = StashItem(stash: WestendStub.address, controller: WestendStub.address)
        presenter.didReceiveStashItem(result: .success(stashItem))

        let publicKeyData = try stashItem.stash.toAccountId()
        let stashAccountId = try stashItem.stash.toAccountId()
        let stashAccount = ChainAccountResponse(
            chainId: chain.chainId,
            accountId: stashAccountId,
            publicKey: publicKeyData,
            name: "test",
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false
        )

        presenter.didReceiveStash(result: .success(stashAccount))

        // when

        presenter.updateAmount(0.1)
        presenter.handleContinueAction()

        // then
        wait(for: [continueExpectation], timeout: Constants.defaultExpectationDuration)

        // given
        let errorAlertExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                errorAlertExpectation.fulfill()
            }
        }
        // empty balance & extra fee is received
        presenter.didReceiveAccountInfo(result: .success(nil))
        let paymentInfoWithExtraFee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600000000002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(paymentInfoWithExtraFee))

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [errorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
