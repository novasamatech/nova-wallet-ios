import Foundation
import IrohaCrypto
import SoraKeystore
import SoraUI
import SoraFoundation
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
        resolution: ExtrinsicSenderResolution.ResolvedProxy,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    )

    func presentNotEnoughProxyPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedProxy,
        completion: @escaping TransactionSigningClosure
    )
}

final class TransactionSigningPresenter: TransactionSigningPresenting {
    weak var view: UIViewController?

    private var flowHolder: AnyObject?

    init(view: UIViewController? = nil) {
        self.view = view
    }

    private var presentationController: UIViewController? {
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        return view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController
    }

    private func present(signingView: ControllerBackedProtocol, completion: @escaping TransactionSigningClosure) {
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

    private func createProxySigningClosure(
        for data: Data,
        proxy: MetaChainAccountResponse,
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
                senderResolution: .current(proxy.chainAccount),
                extrinsicMemo: substrateContext.extrinsicMemo,
                codingFactory: substrateContext.codingFactory
            )
            let signingWrapper = signingWrapperFactory.createSigningWrapper(
                for: proxy.metaId,
                accountResponse: proxy.chainAccount
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

    private func createProxyValidationClosure(
        resolution: ExtrinsicSenderResolution.ResolvedProxy,
        extrinsicMemo: ExtrinsicBuilderMemoProtocol
    ) -> (@escaping ProxySignValidationCompletion) -> Void {
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

    func presentProxyFlow(
        for data: Data,
        proxiedId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedProxy,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        guard let proxy = resolution.proxyAccount else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let signClosure = createProxySigningClosure(
            for: data,
            proxy: proxy,
            substrateContext: substrateContext,
            completion: completion
        )

        let validationClosure = createProxyValidationClosure(
            resolution: resolution,
            extrinsicMemo: substrateContext.extrinsicMemo
        )

        let cancelClosure: () -> Void = {
            completion(.failure(ProxySigningWrapperError.canceled))
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

        guard let presentationController = self.presentationController else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let confirmationPresenter = ProxySignConfirmationViewFactory.createPresenter(
            from: proxiedId,
            proxyName: proxy.chainAccount.name,
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

    func presentNotEnoughProxyPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedProxy,
        completion: @escaping TransactionSigningClosure
    ) {
        let completionClosure: () -> Void = {
            completion(.failure(ProxySigningWrapperError.closed))
        }

        let accountRequest = resolution.chain.accountRequest()

        guard
            let proxiedWallet = resolution.allWallets.first(where: { $0.metaId == metaId }),
            let proxyModel = proxiedWallet.proxy(),
            let proxyWallet = resolution.allWallets.first(
                where: { $0.fetch(for: accountRequest)?.accountId == proxyModel.accountId }
            ) else {
            return
        }

        let type = LocalizableResource<String> { locale in
            proxyModel.type.title(locale: locale)
        }

        guard
            let notEnoughProxyPermissionView = ProxyMessageSheetViewFactory.createNotEnoughPermissionsView(
                proxiedName: resolution.proxiedAccount.name,
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
