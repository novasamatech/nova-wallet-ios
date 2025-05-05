import UIKit
import Foundation_iOS

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
}

// MARK: Private

private extension AssetReceiveViewController {
    func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.shareButton.imageWithTitleView?.title = R.string.localizable.walletReceiveShareTitle(
            preferredLanguages: languages
        )
        rootView.accountAddressView.copyButton.imageWithTitleView?.title = R.string.localizable.commonCopyAddress(
            preferredLanguages: languages
        ).capitalized
        rootView.legacyAddressMessageLabel.text = R.string.localizable.assetReceiveLookingForAddressMessage(
            preferredLanguages: languages
        )
        rootView.viewAddressFormatsButton.setTitle(
            R.string.localizable.assetReceiveViewAddressFormat(
                preferredLanguages: languages
            )
        )
    }

    func setupHandlers() {
        rootView.shareButton.addTarget(
            self,
            action: #selector(actionShare),
            for: .touchUpInside
        )
        rootView.accountAddressView.copyButton.addTarget(
            self,
            action: #selector(actionCopyAddress),
            for: .touchUpInside
        )
        rootView.viewAddressFormatsButton.addTarget(
            self,
            action: #selector(actionViewFormats),
            for: .touchUpInside
        )
    }

    func updateTitleDetails(
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

    func updateNavigationBar() {
        navigationItem.titleView = rootView.chainView
    }

    @objc func actionShare() {
        presenter.share()
    }

    @objc func actionCopyAddress() {
        presenter.copyAddress()
    }

    @objc func actionViewFormats() {
        presenter.viewAddressFormats()
    }
}

// MARK: AssetReceiveViewProtocol

extension AssetReceiveViewController: AssetReceiveViewProtocol {
    func didReceive(
        addressViewModel: AccountAddressViewModel,
        networkName: String,
        token: String
    ) {
        updateTitleDetails(
            chainName: networkName,
            token: token
        )

        rootView.accountAddressView.titleLabel.text = addressViewModel.walletName
        rootView.accountAddressView.addressLabel.text = addressViewModel.address

        if addressViewModel.hasLegacyAddress {
            rootView.showLegacyAddressMessage()
        }
    }

    func didReceive(qrResult: QRCodeWithLogoFactory.QRCreationResult) {
        rootView.qrView.bind(viewModel: qrResult)
    }

    func didReceive(networkViewModel: NetworkViewModel) {
        rootView.chainView.bind(viewModel: networkViewModel)
        updateNavigationBar()
    }
}

// MARK: Localizable

extension AssetReceiveViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

struct AccountAddressViewModel {
    let walletName: String?
    let address: String?
    let hasLegacyAddress: Bool
}
