import UIKit
import SoraFoundation

final class ControllerAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountViewLayout

    let presenter: ControllerAccountPresenterProtocol

    init(
        presenter: ControllerAccountPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    override func loadView() {
        view = ControllerAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupActions()
        presenter.setup()
    }

    private func setupActions() {
        rootView.actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
        rootView.bannerView.linkButton?.addTarget(self, action: #selector(handleLearnMoreAction), for: .touchUpInside)
        rootView.stashAccountView.addTarget(self, action: #selector(handleStashAction), for: .touchUpInside)
        rootView.controllerAccountView.addTarget(self, action: #selector(handleControllerAction), for: .touchUpInside)
    }

    @objc
    private func handleActionButton() {
        presenter.proceed()
    }

    @objc
    private func handleLearnMoreAction() {
        presenter.selectLearnMore()
    }

    @objc
    private func handleStashAction() {
        presenter.handleStashAction()
    }

    @objc
    private func handleControllerAction() {
        presenter.handleControllerAction()
    }
}

extension ControllerAccountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingControllerAccountTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.locale = selectedLocale
        }
    }
}

extension ControllerAccountViewController: ControllerAccountViewProtocol {
    func reload(with viewModel: ControllerAccountViewModel) {
        rootView.stashAccountView.bind(viewModel: viewModel.stashViewModel)

        rootView.controllerAccountView.bind(viewModel: viewModel.controllerViewModel)

        let isEnabled = viewModel.actionButtonIsEnabled
        rootView.actionButton.set(enabled: isEnabled)

        let shouldShowAccountWarning = viewModel.currentAccountIsController

        rootView.setIsControllerHintShown(shouldShowAccountWarning)
        rootView.actionButton.isHidden = shouldShowAccountWarning

        rootView.controllerAccountView.shouldEnableAction = viewModel.canChooseOtherController
    }

    func didCompleteControllerSelection() {
        rootView.controllerAccountView.deactivate(animated: true)
    }
}
