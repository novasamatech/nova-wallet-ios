import UIKit
import SnapKit
import Foundation_iOS
import NovaAnalytics

final class SwapsTabHostViewController: UIViewController {
    let assetListObservable: AssetListModelObservable
    let prefillResolver: SwapSetupPrefillResolving
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let localizationManager: LocalizationManagerProtocol

    private var contentController: UIViewController?
    private var needsRebuild = true

    init(
        assetListObservable: AssetListModelObservable,
        prefillResolver: SwapSetupPrefillResolving,
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.assetListObservable = assetListObservable
        self.prefillResolver = prefillResolver
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

        install(SwapsTabPlaceholderViewController(localizationManager: localizationManager))
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
            install(SwapsTabPlaceholderViewController(localizationManager: localizationManager))
        }
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

        install(SwapsTabPlaceholderViewController(localizationManager: localizationManager))

        if viewIfLoaded?.window != nil {
            rebuildIfNeeded()
        }
    }
}

// MARK: SwapsTabFormResetting

extension SwapsTabHostViewController: SwapsTabFormResetting {}

// MARK: HiddableBarWhenPushed

extension SwapsTabHostViewController: HiddableBarWhenPushed {}
