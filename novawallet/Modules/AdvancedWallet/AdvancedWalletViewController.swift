import UIKit
import SoraFoundation

final class AdvancedWalletViewController: UIViewController, ViewHolder {
    typealias RootViewType = AdvancedWalletViewLayout

    let presenter: AdvancedWalletPresenterProtocol

    private var substrateDerivationPathViewModel: InputViewModelProtocol?
    private var ethereumDerivationPathViewModel: InputViewModelProtocol?

    init(presenter: AdvancedWalletPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AdvancedWalletViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOnSubstrateCryptoType),
            for: .touchUpInside
        )

        rootView.ethereumCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOnEthereumCryptoType),
            for: .touchUpInside
        )

        rootView.proceedButton.addTarget(self, action: #selector(actionApply), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = "Advanced"

        let substrateCryptoView = rootView.substrateCryptoTypeView.actionControl.contentView
        substrateCryptoView?.titleLabel.text = R.string.localizable.commonCryptoTypeSubstrate(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.substrateTextField.title = R.string.localizable.commonSecretDerivationPathSubstrate(
            preferredLanguages: selectedLocale.rLanguages
        )

        let ethereumCryptoView = rootView.ethereumCryptoTypeView.actionControl.contentView
        ethereumCryptoView?.titleLabel.text = R.string.localizable.commonCryptoTypeSubstrate(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.ethereumTextField.title = R.string.localizable.commonSecretDerivationPathEthereum(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.proceedButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.substrateTextField.addTarget(self, action: #selector(actionFieldChanged(sender:)), for: .editingChanged)
        rootView.ethereumTextField.addTarget(self, action: #selector(actionFieldChanged(sender:)), for: .editingChanged)
    }

    @objc private func actionApply() {
        presenter.apply()
    }

    @objc private func actionOnSubstrateCryptoType() {
        presenter.selectSubstrateCryptoType()
    }

    @objc private func actionOnEthereumCryptoType() {
        presenter.selectSubstrateCryptoType()
    }

    @objc private func actionFieldChanged(sender _: AnyObject) {}
}

extension AdvancedWalletViewController: AdvancedWalletViewProtocol {
    func setSubstrateCrypto(viewModel _: SelectableViewModel<TitleWithSubtitleViewModel>?) {}

    func setEthreumCrypto(viewModel _: SelectableViewModel<TitleWithSubtitleViewModel>?) {}

    func setSubstrateDerivationPath(viewModel _: InputViewModelProtocol?) {}

    func setEthereumDerivationPath(viewModel _: InputViewModelProtocol?) {}

    func didCompleteCryptoTypeSelection() {
        rootView.substrateCryptoTypeView.actionControl.imageIndicator.deactivate()
        rootView.ethereumCryptoTypeView.actionControl.imageIndicator.deactivate()
    }
}

extension AdvancedWalletViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
