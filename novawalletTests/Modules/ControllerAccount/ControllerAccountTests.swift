import XCTest
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
@testable import novawallet

class ControllerAccountTests: XCTestCase {
    func testContinueAction() throws {
        let wireframe = MockControllerAccountWireframeProtocol()
        let interactor = MockControllerAccountInteractorInputProtocol()
        let viewModelFactory = MockControllerAccountViewModelFactoryProtocol()
        let view = MockControllerAccountViewProtocol()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            assetInfo: chainAsset.assetDisplayInfo,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        dataValidatingFactory.view = view

        // given
        let showConfirmationExpectation = XCTestExpectation(
            description: "Show Confirmation screen if user has sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub.showConfirmation(from: any(), controllerAccountItem: any())).then { _ in
                showConfirmationExpectation.fulfill()
            }
        }

        stub(viewModelFactory) { stub in
            when(stub.createViewModel(
                stashItem: any(),
                stashAccountItem: any(),
                chosenAccountItem: any(),
                isDeprecated: any()
            ))
                .then { _ in ControllerAccountViewModel(
                    stashViewModel: WalletAccountViewModel.empty,
                    controllerViewModel: WalletAccountViewModel.empty,
                    currentAccountIsController: false,
                    isDeprecated: false,
                    hasChangesToSave: true
                ) }
        }
        stub(view) { stub in
            when(stub.reload(with: any())).thenDoNothing()
            when(stub.didCompleteControllerSelection()).thenDoNothing()
        }

        let controllerAddress = try Data.random(of: 32)!.toAddress(using: chain.chainFormat)
        let stashAddress = try Data.random(of: 32)!.toAddress(using: chain.chainFormat)

        let stashItem = StashItem(stash: stashAddress, controller: controllerAddress, chainId: chain.chainId)
        presenter.didReceiveStashItem(result: .success(stashItem))

        let controllerId = try controllerAddress.toAccountId()
        let controllerAccount = ChainAccountResponse(
            metaId: UUID().uuidString,
            chainId: chain.chainId,
            accountId: controllerId,
            publicKey: controllerId,
            name: "username",
            cryptoType: .substrateEcdsa,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false,
            type: .secrets
        )

        let metaAccountResponse = MetaChainAccountResponse(
            metaId: UUID().uuidString,
            substrateAccountId: controllerId,
            ethereumAccountId: nil,
            walletIdenticonData: nil,
            delegationId: nil,
            chainAccount: controllerAccount
        )

        presenter.didReceiveControllerAccount(result: .success(metaAccountResponse))

        let controllerAccountInfo = AccountInfo(
            nonce: 0,
            data: AccountData(free: 100_000_000_000_000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveControllerAccountInfo(result: .success(controllerAccountInfo), address: controllerAddress)

        let stashAccountId = try! stashAddress.toAccountId()
        let stashBalance = AssetBalance(
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: chain.utilityAsset()!.assetId),
            accountId: stashAccountId,
            freeInPlank: 100_000_000_000_000,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .fungibleTrait,
            blocked: false
        )

        presenter.didReceiveAccountBalance(result: .success(stashBalance), address: stashAddress)

        let fee = ExtrinsicFee(amount: 12_600_002_654, payer: nil, weight: .init(refTime: 331_759_000, proofSize: 0))
        presenter.didReceiveFee(result: .success(fee))

        // when
        presenter.proceed()

        // then
        wait(for: [showConfirmationExpectation], timeout: Constants.defaultExpectationDuration)

        // otherwise
        let showErrorAlertExpectation = XCTestExpectation(
            description: "Show error alert if user has not sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub.present(message: any(), title: any(), closeAction: any(), from: any())).then { _ in
                showErrorAlertExpectation.fulfill()
            }
        }

        let assetSmallBalance = AssetBalance(
            chainAssetId: chain.utilityChainAssetId()!,
            accountId: stashAccountId,
            freeInPlank: 10,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .fungibleTrait,
            blocked: false
        )

        presenter.didReceiveAccountBalance(result: .success(assetSmallBalance), address: stashAddress)

        let extraFee = ExtrinsicFee(amount: 126_000_002_654, payer: nil, weight: .init(refTime: 331_759_000, proofSize: 0))
        presenter.didReceiveFee(result: .success(extraFee))

        // when
        presenter.proceed()

        // then
        wait(for: [showErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
