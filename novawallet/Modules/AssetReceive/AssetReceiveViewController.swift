import UIKit
import SoraFoundation

final class AssetReceiveViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetReceiveViewLayout

    let presenter: AssetReceivePresenterProtocol
    private var cachedBounds: CGRect?
    private var token: String = ""

    init(
        presenter: AssetReceivePresenterProtocol,
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
        view = AssetReceiveViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard cachedBounds != view.bounds else {
            return
        }
        cachedBounds = view.bounds
        presenter.set(qrCodeSize: AssetReceiveViewLayout.Constants.calculateQRsize(view.bounds))
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.titleLabel.text = R.string.localizable.walletReceiveDescription(preferredLanguages: languages)
        rootView.shareButton.imageWithTitleView?.title = R.string.localizable.walletReceiveShareTitle(preferredLanguages: languages)
        update(token: token)
    }

    private func setupHandlers() {
        rootView.shareButton.addTarget(self, action: #selector(didTapShare), for: .touchUpInside)
        rootView.accountDetailsView.addTarget(self, action: #selector(didTapOnAccount), for: .touchUpInside)
    }

    private func update(token: String) {
        self.token = token
        navigationItem.title = R.string.localizable.walletReceiveTitleFormat(
            token,
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc private func didTapShare() {
        presenter.share()
    }

    @objc private func didTapOnAccount() {
        presenter.presentAccountOptions()
    }
}

extension AssetReceiveViewController: AssetReceiveViewProtocol {
    func didReceive(chainAccountViewModel: ChainAccountViewModel, token: String) {
        rootView.accountDetailsView.chainAccountView.bind(viewModel: chainAccountViewModel)
        update(token: token)
    }

    func didReceive(qrImage: UIImage) {
        rootView.qrView.imageView.image = qrImage
    }
}

extension AssetReceiveViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
