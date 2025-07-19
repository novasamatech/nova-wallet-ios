import Foundation
import NovaCrypto
import Keystore_iOS
import UIKit_iOS
import Foundation_iOS
import SubstrateSdk

typealias TransactionSigningResult = Result<IRSignatureProtocol, Error>
typealias TransactionSigningClosure = (TransactionSigningResult) -> Void

protocol TransactionSigningPresenting: AnyObject {
    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: ParitySignerConfirmationParams,
        completion: @escaping TransactionSigningClosure
    )

    func presentLedgerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: LedgerTxConfirmationParams,
        completion: @escaping TransactionSigningClosure
    )

    func presentNotEnoughProxyPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    )

    func presentDelegatedSigningFlow(
        for data: Data,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    )
}

final class TransactionSigningPresenter {
    weak var view: UIViewController?

    private var flowHolder: AnyObject?

    init(view: UIViewController? = nil) {
        self.view = view
    }
}

// MARK: - Private

private extension TransactionSigningPresenter {
    var presentationController: UIViewController? {
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        return view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController
    }

    func present(signingView: ControllerBackedProtocol, completion: @escaping TransactionSigningClosure) {
        guard let controller = presentationController else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: signingView.controller,
            barSettings: barSettings
        ) {
            completion(.failure(HardwareSigningError.signingCancelled))
        }

        controller.presentWithCardLayout(navigationController, animated: true)
    }

    func createDelegateSigningClosure(
        for data: Data,
        delegate: MetaChainAccountResponse,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) -> () -> Void {
        { [weak self] in
            guard let strongSelf = self else {
                return
            }

            let signingWrapperFactory = SigningWrapperFactory(
                uiPresenter: strongSelf,
                keystore: Keychain(),
                settingsManager: SettingsManager.shared
            )

            let context = ExtrinsicSigningContext.Substrate(
                senderResolution: .current(delegate.chainAccount),
                extrinsicMemo: substrateContext.extrinsicMemo,
                codingFactory: substrateContext.codingFactory
            )
            let signingWrapper = signingWrapperFactory.createSigningWrapper(
                for: delegate.metaId,
                accountResponse: delegate.chainAccount
            )

            DispatchQueue.global().async {
                do {
                    let signature = try signingWrapper.sign(data, context: .substrateExtrinsic(context))

                    completion(.success(signature))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - TransactionSigningPresenting

extension TransactionSigningPresenter: TransactionSigningPresenting {
    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: ParitySignerConfirmationParams,
        completion: @escaping TransactionSigningClosure
    ) {
        guard let paritySignerView = ParitySignerTxQrViewFactory.createView(
            with: data,
            metaId: metaId,
            chainId: chainId,
            params: params,
            completion: completion
        ) else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        present(signingView: paritySignerView, completion: completion)
    }

    func presentLedgerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: LedgerTxConfirmationParams,
        completion: @escaping TransactionSigningClosure
    ) {
        guard
            let ledgerView = LedgerTxConfirmViewFactory.createView(
                with: data,
                metaId: metaId,
                chainId: chainId,
                params: params,
                completion: completion
            ) else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        present(signingView: ledgerView, completion: completion)
    }

    func presentNotEnoughProxyPermissionsFlow(
        for _: String,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    ) {
        let completionClosure: () -> Void = {
            completion(.failure(DelegatedSigningWrapperError.closed))
        }

        guard
            let proxyWallet = resolution.getNotEnoughPermissionProxyWallet(),
            let proxiedWallet = resolution.getNonResolvedProxiedWallet(),
            let proxyModel = proxiedWallet.proxy else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let type = LocalizableResource<String> { locale in
            proxyModel.type.title(locale: locale)
        }

        guard
            let notEnoughProxyPermissionView = DelegatedMessageSheetViewFactory.createNotEnoughPermissionsView(
                proxiedName: proxiedWallet.name,
                proxyName: proxyWallet.name,
                type: type,
                completionCallback: completionClosure
            ) else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        let optionalController = view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController

        guard let presentationController = optionalController else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        presentationController.present(notEnoughProxyPermissionView.controller, animated: true)
    }

    func presentDelegatedSigningFlow(
        for data: Data,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        guard let delegate = resolution.delegateAccount else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let signClosure = createDelegateSigningClosure(
            for: data,
            delegate: delegate,
            substrateContext: substrateContext,
            completion: completion
        )

        let cancelClosure: () -> Void = {
            completion(.failure(DelegatedSigningWrapperError.canceled))
        }

        let completionClosure: DelegatedSignValidationCompletion = { [weak self] isSuccess in
            self?.flowHolder = nil

            if isSuccess {
                signClosure()
            } else {
                cancelClosure()
            }
        }

        // Calls must be batched before passing to validation as we require a single call
        let allCalls = substrateContext.extrinsicMemo.restoreBuilder().getCalls()

        guard
            let viewController = presentationController,
            allCalls.count == 1,
            let call = allCalls.first,
            let confirmationPresenter = DelegatedSignValidationViewFactory.createView(
                from: ControllerBacked(controller: viewController),
                resolution: resolution,
                call: call,
                completionClosure: completionClosure
            ) else {
            cancelClosure()
            return
        }

        flowHolder = confirmationPresenter

        confirmationPresenter.setup()
    }
}
