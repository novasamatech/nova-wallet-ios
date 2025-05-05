import XCTest
import Cuckoo
import Operation_iOS
import Foundation_iOS

import NovaCrypto
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

        let asset = chain.utilityAsset()!
        let assetInfo = asset.displayInfo

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
        let stashItem = StashItem(stash: WestendStub.address, controller: WestendStub.address, chainId: chain.chainId)
        let stashAccountId = try stashItem.stash.toAccountId()
        let assetBalance = AssetBalance(
            chainAssetId: chain.utilityChainAssetId()!,
            accountId: stashAccountId,
            freeInPlank: 100000000000000,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .fungibleTrait,
            blocked: false
        )

        presenter.didReceiveAccountBalance(result: .success(assetBalance))

        let paymentInfo = ExtrinsicFee(amount: 12600002654,payer: nil, weight: .init(refTime: 331759000, proofSize: 0))
        presenter.didReceiveFee(result: .success(paymentInfo))

        presenter.didReceiveStashItem(result: .success(stashItem))

        let publicKeyData = try stashItem.stash.toAccountId()
        let stashAccount = ChainAccountResponse(
            metaId: UUID().uuidString,
            chainId: chain.chainId,
            accountId: stashAccountId,
            publicKey: publicKeyData,
            name: "test",
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false,
            type: .secrets
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
        presenter.didReceiveAccountBalance(result: .success(nil))
        let paymentInfoWithExtraFee = ExtrinsicFee(amount: 12600000000002654, payer: nil, weight: .init(refTime: 331759000, proofSize: 0))
        presenter.didReceiveFee(result: .success(paymentInfoWithExtraFee))

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [errorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
