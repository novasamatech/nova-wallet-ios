import UIKit
import CommonWallet
import SoraUI
import SoraFoundation

final class AssetDetailsView: BaseAccountDetailsContainingView {
    var contentInsets: UIEdgeInsets = .zero

    var preferredContentHeight: CGFloat { 350.0 }

    @IBOutlet var separators: [BorderedContainerView]!

    // Header
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconView: UIImageView!
    @IBOutlet private var priceLabel: UILabel!
    @IBOutlet private var priceChangeLabel: UILabel!

    // Balances widget
    @IBOutlet var widgetTitleLabel: UILabel!
    @IBOutlet var totalSectionTitleLabel: UILabel!
    @IBOutlet var totalSectionTokenLabel: UILabel!
    @IBOutlet var totalSectionFiatLabel: UILabel!
    @IBOutlet var transferableSectionTitleLabel: UILabel!
    @IBOutlet var transferableSectionTokenLabel: UILabel!
    @IBOutlet var transferableSectionFiatLabel: UILabel!
    @IBOutlet var lockedSectionTitleLabel: UILabel!
    @IBOutlet var lockedSectionTokenLabel: UILabel!
    @IBOutlet var lockedSectionFiatLabel: UILabel!

    // Action buttons
    @IBOutlet private var sendButton: RoundedButton!
    @IBOutlet private var receiveButton: RoundedButton!
    @IBOutlet private var buyButton: RoundedButton!

    private var localizedTitle: LocalizableResource<String>?
    private var iconViewModel: WalletImageViewModelProtocol?

    private var sendCommand: WalletCommandProtocol?
    private var receiveCommand: WalletCommandProtocol?
    private var buyCommand: WalletCommandProtocol?
    private var lockedInfoCommand: WalletCommandProtocol?

    private var backgroundView = MultigradientView.background

    private let networkView: RawChainView = {
        let chainView = RawChainView()
        chainView.iconDetailsView.detailsLabel.lineBreakMode = .byCharWrapping
        return chainView
    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        setupBackgroundView()
        setupNetworkView()

        separators.forEach {
            $0.strokeWidth = UIConstants.separatorHeight
        }

        setupDefaultValues()
    }

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated _: Bool) {
        self.contentInsets = contentInsets
    }

    func bind(title: LocalizableResource<String>, iconViewModel: WalletImageViewModelProtocol?) {
        localizedTitle = title

        titleLabel.text = title.value(for: selectedLocale)

        iconViewModel?.cancel()
        iconView.image = nil

        self.iconViewModel = iconViewModel

        iconViewModel?.loadImage { [weak self] image, _ in
            self?.iconView.image = image
        }
    }

    func bind(networkName: String, iconViewModel: ImageViewModelProtocol) {
        networkView.bind(name: networkName, iconViewModel: iconViewModel)
    }

    func bindActions(
        send: WalletCommandProtocol?,
        receive: WalletCommandProtocol?,
        buy: WalletCommandProtocol?
    ) {
        sendCommand = send
        receiveCommand = receive
        buyCommand = buy

        sendButton.isEnabled = (sendCommand != nil)
        receiveButton.isEnabled = (receiveCommand != nil)
        buyButton.isEnabled = (buyCommand != nil)
    }

    func bind(viewModels: [WalletViewModelProtocol]) {
        if let assetViewModel = viewModels
            .first(where: { $0 is AssetDetailsViewModel }) as? AssetDetailsViewModel {
            bind(assetViewModel: assetViewModel)
        }

        setNeedsLayout()
    }

    private func setupLocalization() {
        titleLabel.text = localizedTitle?.value(for: selectedLocale)

        let languages = selectedLocale.rLanguages
        widgetTitleLabel.text = R.string.localizable.walletBalancesWidgetTitle(
            preferredLanguages: languages
        )

        totalSectionTitleLabel.text = R.string.localizable.walletTransferTotalTitle(
            preferredLanguages: languages
        )

        transferableSectionTitleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: languages
        )

        lockedSectionTitleLabel.text = R.string.localizable.walletBalanceLocked(
            preferredLanguages: languages
        )

        sendButton.imageWithTitleView?.title = R.string.localizable.walletSendTitle(
            preferredLanguages: languages
        )

        sendButton.invalidateLayout()

        receiveButton.imageWithTitleView?.title = R.string.localizable.walletAssetReceive(
            preferredLanguages: languages
        )

        receiveButton.invalidateLayout()

        buyButton.imageWithTitleView?.title = R.string.localizable.walletAssetBuy(
            preferredLanguages: languages
        )

        buyButton.invalidateLayout()
    }

    private func setupBackgroundView() {
        insertSubview(backgroundView, at: 0)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupNetworkView() {
        addSubview(networkView)
        networkView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(titleLabel.snp.centerY)
            make.height.equalTo(16.0)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(4.0)
        }
    }

    private func setupDefaultValues() {
        priceLabel.text = ""
        totalSectionTokenLabel.text = ""
        totalSectionFiatLabel.text = ""
        transferableSectionTokenLabel.text = ""
        transferableSectionFiatLabel.text = ""
        lockedSectionTokenLabel.text = ""
        lockedSectionFiatLabel.text = ""
        priceChangeLabel.text = ""
    }

    private func bind(assetViewModel: AssetDetailsViewModel) {
        lockedInfoCommand = assetViewModel.infoDetailsCommand

        priceLabel.text = assetViewModel.price

        // Balances widget
        totalSectionTokenLabel.text = assetViewModel.totalBalance.amount
        totalSectionFiatLabel.text = assetViewModel.totalBalance.price

        transferableSectionTokenLabel.text = assetViewModel.transferableBalance.amount
        transferableSectionFiatLabel.text = assetViewModel.transferableBalance.price

        lockedSectionTokenLabel.text = assetViewModel.lockedBalance.amount
        lockedSectionFiatLabel.text = assetViewModel.lockedBalance.price

        switch assetViewModel.priceChangeViewModel {
        case let .goingUp(displayString):
            priceChangeLabel.text = displayString
            priceChangeLabel.textColor = R.color.colorGreen()!
        case let .goingDown(displayString):
            priceChangeLabel.text = displayString
            priceChangeLabel.textColor = R.color.colorRed()!
        }
    }

    @IBAction private func actionSend() {
        try? sendCommand?.execute()
    }

    @IBAction private func actionReceive() {
        try? receiveCommand?.execute()
    }

    @IBAction private func actionBuy() {
        try? buyCommand?.execute()
    }

    @IBAction private func actionFrozen() {
        try? lockedInfoCommand?.execute()
    }
}

extension AssetDetailsView: Localizable {
    func applyLocalization() {
        setupLocalization()
    }
}
