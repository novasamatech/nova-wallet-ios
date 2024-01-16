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
        rootView.accountInputView.addTarget(
            self,
            action: #selector(actionAddressChange),
            for: .editingChanged
        )
        rootView.yourWalletsControl.addTarget(
            self,
            action: #selector(actionYourWallets),
            for: .touchUpInside
        )
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
        rootView.accountInputView.scanButton.addTarget(
            self,
            action: #selector(actionAddressScan),
            for: .touchUpInside
        )

        rootView.web3NameReceipientView.delegate = self
        rootView.accountInputView.delegate = self
    }

    @objc
    private func proxyInfoAction() {
        presenter.showDepositInfo()
    }

    @objc private func actionAddressChange() {
        let partialAddress = rootView.accountInputView.textField.text ?? ""
        presenter.updateAuthority(partialAddress: partialAddress)

        updateActionButtonState()
    }

    @objc func actionYourWallets() {
        presenter.didTapOnYourWallets()
    }

    func updateActionButtonState() {
        if !rootView.accountInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .transferSetupEnterAddress(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.actionButton.invalidateLayout()
    }

    @objc func actionAddressScan() {
        presenter.scanAddressCode()
    }

    @objc func actionProceed() {
        if rootView.accountInputView.textField.isFirstResponder {
            let partialAddress = rootView.accountInputView.textField.text ?? ""
            presenter.complete(authority: partialAddress)

            rootView.accountInputView.textField.resignFirstResponder()
        }

        presenter.proceed()
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

    func didReceiveAccountInput(viewModel: InputViewModelProtocol) {
        rootView.accountInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveAuthorityInputState(focused: Bool, empty: Bool?) {
        if focused {
            rootView.accountInputView.textField.becomeFirstResponder()
        } else {
            rootView.accountInputView.textField.resignFirstResponder()
        }
        if empty == true {
            rootView.accountInputView.actionClear()
        }
    }

    func didReceiveWeb3NameAuthority(viewModel: LoadableViewModelState<Web3NameReceipientView.Model>) {
        rootView.web3NameReceipientView.bind(viewModel: viewModel)
    }

    func didReceiveYourWallets(state: YourWalletsControl.State) {
        rootView.yourWalletsControl.apply(state: state)
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

extension StakingSetupProxyViewController: Web3NameReceipientViewDelegate {
    func didTapOnAccountList() {}

    func didTapOnAccount() {
        presenter.showWeb3NameAuthority()
    }
}
