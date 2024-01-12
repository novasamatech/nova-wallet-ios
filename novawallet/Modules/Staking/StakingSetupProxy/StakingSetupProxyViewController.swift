import UIKit
import SoraFoundation

final class StakingSetupProxyViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingSetupProxyViewLayout

    let presenter: StakingSetupProxyPresenterProtocol
    private var token: String = ""

    init(
        presenter: StakingSetupProxyPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingSetupProxyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupLocalization()
        setupHandlers()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        let strings = R.string.localizable.self

        rootView.titleLabel.text = strings.stakingSetupProxyTitle(token, preferredLanguages: languages)
        rootView.authorityLabel.text = strings.stakingSetupProxyAuthority(preferredLanguages: languages)

        let selectYourWalletTitle = strings.assetsSelectSendYourWallets(preferredLanguages: languages)
        rootView.yourWalletsControl.bind(model: .init(
            name: selectYourWalletTitle,
            image: R.image.iconUsers()
        ))

        rootView.proxyDepositView.titleButton.imageWithTitleView?.title = strings.stakingSetupProxyDeposit(
            preferredLanguages: languages
        )
        rootView.feeView.locale = selectedLocale
        rootView.accountInputView.locale = selectedLocale
    }

    private func setupHandlers() {
        rootView.proxyDepositView.addTarget(
            self,
            action: #selector(proxyInfoAction),
            for: .touchUpInside
        )
        rootView.accountInputView.delegate = self
    }

    @objc
    private func proxyInfoAction() {
        presenter.showDepositInfo()
    }
}

extension StakingSetupProxyViewController: StakingSetupProxyViewProtocol {
    func didReceiveProxyDeposit(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.proxyDepositView.bind(loadableViewModel: viewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeView.bind(viewModel: viewModel)
    }

    func didReceive(token: String) {
        self.token = token
        rootView.titleLabel.text = R.string.localizable.stakingSetupProxyTitle(
            token,
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

extension StakingSetupProxyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension StakingSetupProxyViewController: AccountInputViewDelegate {
    func accountInputViewWillStartEditing(_: AccountInputView) {}

    func accountInputViewDidEndEditing(_ inputView: AccountInputView) {
        presenter.complete(authority: inputView.textField.text ?? "")
    }

    func accountInputViewShouldReturn(_ inputView: AccountInputView) -> Bool {
        inputView.textField.resignFirstResponder()
        return true
    }

    func accountInputViewDidPaste(_ inputView: AccountInputView) {
        if !inputView.textField.isFirstResponder {
            presenter.complete(authority: inputView.textField.text ?? "")
        }
    }
}
