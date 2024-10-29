import UIKit
import SoraFoundation

final class AssetReceiveViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetReceiveViewLayout

    let presenter: AssetReceivePresenterProtocol
    private var cachedBoundsWidth: CGFloat?

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
        guard cachedBoundsWidth != view.bounds.width,
              let qrCodeSize = AssetReceiveViewLayout.Constants.calculateQRsize(view.bounds.width) else {
            return
        }

        cachedBoundsWidth = view.bounds.width
        presenter.set(qrCodeSize: qrCodeSize)
    }

    private func setupLocalization() {
        rootView.shareButton.imageWithTitleView?.title = R.string.localizable.walletReceiveShareTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupHandlers() {
        rootView.shareButton.addTarget(self, action: #selector(didTapShare), for: .touchUpInside)
        rootView.accountDetailsView.addTarget(self, action: #selector(didTapOnAccount), for: .touchUpInside)
    }

    private func updateTitleDetails(
        chainName: String,
        token: String
    ) {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.walletReceiveTitleFormat(
            token,
            preferredLanguages: languages
        )

        rootView.detailsLabel.text = R.string.localizable.walletReceiveDetailsFormat(
            token,
            chainName,
            preferredLanguages: languages
        )
    }

    private func updateNavigationBar() {
        navigationItem.titleView = rootView.chainView
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

        updateTitleDetails(
            chainName: chainAccountViewModel.networkName,
            token: token
        )
    }

    func didReceive(qrImage: UIImage) {
        rootView.qrView.imageView.image = qrImage
    }

    func didReceive(networkViewModel: NetworkViewModel) {
        rootView.chainView.bind(viewModel: networkViewModel)
        updateNavigationBar()
    }
}

extension AssetReceiveViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
