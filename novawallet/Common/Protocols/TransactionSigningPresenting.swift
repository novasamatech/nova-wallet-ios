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

    func presentProxyFlow(
        for data: Data,
        proxiedId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    )

    func presentNotEnoughProxyPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    )

    func presentMultisigFlow(
        for data: Data,
        multisigAccountId: MetaAccountModel.Id,
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

    func presentDelegatedFlow(
        for data: Data,
        delegatedMetaId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        validationClosure: @escaping (@escaping DelegatedSignValidationCompletion) -> Void,
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

        let confirmSuccessClosure: () -> Void = {
            validationClosure { isSuccess in
                if isSuccess {
                    signClosure()
                } else {
                    cancelClosure()
                }
            }
        }

        guard
            let presentationController = self.presentationController,
            let delegationType = resolution.allWallets.first(
                where: { $0.metaId == delegatedMetaId }
            )?.delegationId?.delegationType
        else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let confirmationPresenter = DelegatedSignConfirmationViewFactory.createPresenter(
            from: delegatedMetaId,
            delegationType: delegationType,
            delegateAccountResponse: delegate.chainAccount,
            completionClosure: { [weak self] result in
                self?.flowHolder = nil

                if result {
                    confirmSuccessClosure()
                } else {
                    cancelClosure()
                }
            },
            viewController: presentationController
        )

        flowHolder = confirmationPresenter

        confirmationPresenter.setup()
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

    func createProxyValidationClosure(
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        extrinsicMemo: ExtrinsicBuilderMemoProtocol
    ) -> (@escaping DelegatedSignValidationCompletion) -> Void {
        { [weak self] completionClosure in
            guard
                let strongSelf = self,
                let presentationController = strongSelf.presentationController,
                let presenter = ProxySignValidationViewFactory.createView(
                    from: presentationController,
                    resolvedProxy: resolution,
                    calls: extrinsicMemo.restoreBuilder().getCalls(),
                    completionClosure: { result in
                        self?.flowHolder = nil
                        completionClosure(result)
                    }
                ) else {
                completionClosure(false)
                return
            }

            strongSelf.flowHolder = presenter

            presenter.setup()
        }
    }

    func createMultisigValidationClosure(
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        extrinsicMemo: ExtrinsicBuilderMemoProtocol
    ) -> (@escaping DelegatedSignValidationCompletion) -> Void {
        { [weak self] completionClosure in
            guard
                let strongSelf = self,
                let presentationController = strongSelf.presentationController,
                let presenter = MultisigValidationViewFactory.createView(
                    from: presentationController,
                    resolvedSigner: resolution,
                    calls: extrinsicMemo.restoreBuilder().getCalls(),
                    completionClosure: { result in
                        self?.flowHolder = nil
                        completionClosure(result)
                    }
                ) else {
                completionClosure(false)
                return
            }

            strongSelf.flowHolder = presenter

            presenter.setup()
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

    func presentProxyFlow(
        for data: Data,
        proxiedId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        let validationClosure = createProxyValidationClosure(
            resolution: resolution,
            extrinsicMemo: substrateContext.extrinsicMemo
        )

        presentDelegatedFlow(
            for: data,
            delegatedMetaId: proxiedId,
            resolution: resolution,
            substrateContext: substrateContext,
            validationClosure: validationClosure,
            completion: completion
        )
    }

    func presentMultisigFlow(
        for data: Data,
        multisigAccountId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        let validationClosure = createMultisigValidationClosure(
            resolution: resolution,
            extrinsicMemo: substrateContext.extrinsicMemo
        )

        presentDelegatedFlow(
            for: data,
            delegatedMetaId: multisigAccountId,
            resolution: resolution,
            substrateContext: substrateContext,
            validationClosure: validationClosure,
            completion: completion
        )
    }

    func presentNotEnoughProxyPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    ) {
        let completionClosure: () -> Void = {
            completion(.failure(DelegatedSigningWrapperError.closed))
        }

        let accountRequest = resolution.chain.accountRequest()

        guard
            let proxiedWallet = resolution.allWallets.first(where: { $0.metaId == metaId }),
            let proxyModel = proxiedWallet.proxy,
            let proxyWallet = resolution.allWallets.first(
                where: { $0.fetch(for: accountRequest)?.accountId == proxyModel.accountId }
            ) else {
            return
        }

        let type = LocalizableResource<String> { locale in
            proxyModel.type.title(locale: locale)
        }

        guard
            let notEnoughProxyPermissionView = DelegatedMessageSheetViewFactory.createNotEnoughPermissionsView(
                proxiedName: resolution.delegatedAccount.name,
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
}
