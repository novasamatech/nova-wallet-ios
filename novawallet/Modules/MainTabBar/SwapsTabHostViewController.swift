import UIKit
import SnapKit
import Foundation_iOS
import NovaAnalytics

protocol SwapsTabPairProviding: AnyObject {
    func provideTabPair(completion: @escaping (SwapSetupInitState) -> Void)
}

final class SwapsTabHostViewController: UIViewController {
    let assetListObservable: AssetListModelObservable
    let prefillResolver: SwapSetupPrefillResolving
    let pairPrefillResolver: SwapSetupPrefillResolving
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let localizationManager: LocalizationManagerProtocol

    weak var swapSetupModule: SwapSetupModuleInputProtocol?

    private var contentController: UIViewController?
    private var needsRebuild = true

    init(
        assetListObservable: AssetListModelObservable,
        prefillResolver: SwapSetupPrefillResolving,
        pairPrefillResolver: SwapSetupPrefillResolving,
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.assetListObservable = assetListObservable
        self.prefillResolver = prefillResolver
        self.pairPrefillResolver = pairPrefillResolver
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = R.color.colorSecondaryScreenBackground()

        eventCenter.add(observer: self, dispatchIn: .main)

        installPlaceholder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rebuildIfNeeded()
    }

    func resetForm(prefilledWith initState: SwapSetupInitState?, source: SwapSource) {
        needsRebuild = false
        prefillResolver.cancel()

        if let initState {
            installForm(with: initState, source: source)
        } else {
            resolveAndInstallForm(source: source)
        }
    }
}

// MARK: Private

private extension SwapsTabHostViewController {
    func rebuildIfNeeded() {
        guard needsRebuild else {
            return
        }

        resetForm(prefilledWith: nil, source: .swapsTab)
    }

    func resolveAndInstallForm(source: SwapSource) {
        guard let wallet = walletSettings.value else {
            installForm(with: SwapSetupInitState(payChainAsset: nil), source: source)
            return
        }

        prefillResolver.resolveInitState(for: wallet) { [weak self] initState in
            self?.installForm(with: initState, source: source)
        }
    }

    func installForm(with initState: SwapSetupInitState, source: SwapSource) {
        if let formView = SwapSetupViewFactory.createSwapsTabView(
            initState: initState,
            source: source,
            assetListObservable: assetListObservable,
            formHost: self
        ) {
            install(formView.controller)
        } else {
            installPlaceholder()
        }
    }

    func installPlaceholder() {
        swapSetupModule = nil

        install(SwapsTabPlaceholderViewController(localizationManager: localizationManager))
    }

    func install(_ controller: UIViewController) {
        if let contentController {
            contentController.willMove(toParent: nil)
            contentController.view.removeFromSuperview()
            contentController.removeFromParent()
        }

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        controller.didMove(toParent: self)

        contentController = controller
    }
}

// MARK: EventVisitorProtocol

extension SwapsTabHostViewController: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        needsRebuild = true
        prefillResolver.cancel()
        pairPrefillResolver.cancel()

        installPlaceholder()

        if viewIfLoaded?.window != nil {
            rebuildIfNeeded()
        }
    }
}

// MARK: SwapsTabFormResetting

extension SwapsTabHostViewController: SwapsTabFormResetting {}

// MARK: SwapsTabAssetDetailsShowing

extension SwapsTabHostViewController: SwapsTabAssetDetailsShowing {
    func showAssetDetails(for chainAsset: ChainAsset) {
        let operationState = AssetOperationState(
            assetListObservable: assetListObservable,
            swapCompletionClosure: nil
        )

        guard let detailsView = AssetDetailsContainerViewFactory.createView(
            chainAsset: chainAsset,
            operationState: operationState
        ) else {
            return
        }

        navigationController?.pushViewController(detailsView.controller, animated: true)
    }
}

// MARK: SwapSetupModuleInputOwnerProtocol

extension SwapsTabHostViewController: SwapSetupModuleInputOwnerProtocol {}

// MARK: SwapsTabPairProviding

extension SwapsTabHostViewController: SwapsTabPairProviding {
    func provideTabPair(completion: @escaping (SwapSetupInitState) -> Void) {
        if let swapSetupModule {
            completion(swapSetupModule.currentPairInitState)
            return
        }

        guard let wallet = walletSettings.value else {
            completion(SwapSetupInitState(payChainAsset: nil))
            return
        }

        pairPrefillResolver.resolveInitState(for: wallet) { [weak self] initState in
            guard self?.walletSettings.value?.metaId == wallet.metaId else {
                return
            }

            completion(initState)
        }
    }
}

// MARK: HiddableBarWhenPushed

extension SwapsTabHostViewController: HiddableBarWhenPushed {}
