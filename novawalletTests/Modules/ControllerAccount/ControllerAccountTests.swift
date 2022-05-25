import XCTest
import Cuckoo
import RobinHood
import SubstrateSdk
import SoraKeystore
import SoraFoundation
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
            explorers: nil
        )
        presenter.view = view
        dataValidatingFactory.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { LocalizationManager.shared }
        }

        // given
        let showConfirmationExpectation = XCTestExpectation(
            description: "Show Confirmation screen if user has sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any(), controllerAccountItem: any()).then { _ in
                showConfirmationExpectation.fulfill()
            }
        }

        stub(viewModelFactory) { stub in
            when(stub).createViewModel(stashItem: any(), stashAccountItem: any(), chosenAccountItem: any())
                .then { _ in ControllerAccountViewModel(
                    stashViewModel: WalletAccountViewModel.empty,
                    controllerViewModel: WalletAccountViewModel.empty,
                    currentAccountIsController: false,
                    actionButtonIsEnabled: true
                )}
        }
        stub(view) { stub in
            when(stub).reload(with: any()).thenDoNothing()
            when(stub).didCompleteControllerSelection().thenDoNothing()
        }

        let controllerAddress = try Data.random(of: 32)!.toAddress(using: chain.chainFormat)
        let stashAddress = try Data.random(of: 32)!.toAddress(using: chain.chainFormat)

        let stashItem = StashItem(stash: stashAddress, controller: controllerAddress)
        presenter.didReceiveStashItem(result: .success(stashItem))

        let controllerId = try controllerAddress.toAccountId()
        let controllerAccount = ChainAccountResponse(
            chainId: chain.chainId,
            accountId: controllerId,
            publicKey: controllerId,
            name: "username",
            cryptoType: .substrateEcdsa,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false
        )

        let metaAccountResponse = MetaChainAccountResponse(
            metaId: UUID().uuidString,
            substrateAccountId: controllerId,
            ethereumAccountId: nil,
            chainAccount: controllerAccount
        )

        presenter.didReceiveControllerAccount(result: .success(metaAccountResponse))

        let controllerAccountInfo = AccountInfo(
            nonce: 0,
            data: AccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveControllerAccountInfo(result: .success(controllerAccountInfo), address: controllerAddress)

        let stashAccountInfo = AccountInfo(
            nonce: 0,
            data: AccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveAccountInfo(result: .success(stashAccountInfo), address: stashAddress)

        let fee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600002654", weight: 331759000)
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
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                showErrorAlertExpectation.fulfill()
            }
        }

        let accountInfoSmallBalance = AccountInfo(
            nonce: 0,
            data: AccountData(free: 10, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveAccountInfo(result: .success(accountInfoSmallBalance), address: stashAddress)

        let extraFee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "126000002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(extraFee))

        // when
        presenter.proceed()

        // then
        wait(for: [showErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
