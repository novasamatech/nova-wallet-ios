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
        type: ParitySignerType,
        completion: @escaping TransactionSigningClosure
    )

    func presentLedgerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    )

    func presentProxyFlow(
        for data: Data,
        proxy: MetaChainAccountResponse,
        calls: [JSON],
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

    init(view: UIViewController? = nil) {
        self.view = view
    }

    private func present(signingView: ControllerBackedProtocol, completion: @escaping TransactionSigningClosure) {
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        let optionalController = view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController

        guard let controller = optionalController else {
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

        controller.present(navigationController, animated: true)
    }

    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        type: ParitySignerType,
        completion: @escaping TransactionSigningClosure
    ) {
        guard let paritySignerView = ParitySignerTxQrViewFactory.createView(
            with: data,
            metaId: metaId,
            chainId: chainId,
            type: type,
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
        completion: @escaping TransactionSigningClosure
    ) {
        guard
            let ledgerView = LedgerTxConfirmViewFactory.createView(
                with: data,
                metaId: metaId,
                chainId: chainId,
                completion: completion
            ) else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        present(signingView: ledgerView, completion: completion)
    }

    func presentProxyFlow(
        for data: Data,
        proxy: MetaChainAccountResponse,
        calls: [JSON],
        completion: @escaping TransactionSigningClosure
    ) {
        let settingsManager = SettingsManager.shared

        let completionClosure: () -> Void = {
            let signingWrapperFactory = SigningWrapperFactory(
                uiPresenter: self,
                keystore: Keychain(),
                settingsManager: settingsManager
            )

            let context = ExtrinsicSigningContext.Substrate(
                senderResolution: .current(proxy.chainAccount),
                calls: calls
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

        guard !settingsManager.skipProxyFeeInformation else {
            completionClosure()
            return
        }

        let cancelClosure: () -> Void = {
            completion(.failure(ProxySigningWrapperError.canceled))
        }

        guard
            let proxyConfirmationView = ProxyMessageSheetViewFactory.createSigningView(
                proxyName: proxy.chainAccount.name,
                completionClosure: completionClosure,
                cancelClosure: cancelClosure
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

        presentationController.present(proxyConfirmationView.controller, animated: true)
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
