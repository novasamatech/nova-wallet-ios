import UIKit
import CommonWallet
import SoraUI

final class AssetDetailsView: BaseAccountDetailsContainingView {
    var contentInsets: UIEdgeInsets = .zero

    var preferredContentHeight: CGFloat { 337.0 }

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

    private var actionsViewModel: WalletActionsViewModelProtocol?
    private var assetViewModel: AssetDetailsViewModel?

    override func awakeFromNib() {
        super.awakeFromNib()

        separators.forEach {
            $0.strokeWidth = UIConstants.separatorHeight
        }
    }

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated _: Bool) {
        self.contentInsets = contentInsets
    }

    func bind(viewModels: [WalletViewModelProtocol]) {
        if let assetViewModel = viewModels
            .first(where: { $0 is AssetDetailsViewModel }) as? AssetDetailsViewModel {
            bind(assetViewModel: assetViewModel)
        }

        if let actionsViewModel = viewModels
            .first(where: { $0 is ActionsViewModelProtocol }) as? ActionsViewModelProtocol {
            bind(actionsViewModel: actionsViewModel)
        }

        setNeedsLayout()
    }

    private func bind(assetViewModel: AssetDetailsViewModel) {
        self.assetViewModel?.imageViewModel?.cancel()

        self.assetViewModel = assetViewModel

        titleLabel.text = assetViewModel.title

        iconView.image = nil

        assetViewModel.imageViewModel?.loadImage { [weak self] image, _ in
            self?.iconView.image = image
        }

        priceLabel.text = assetViewModel.price

        // Balances widget
        widgetTitleLabel.text = assetViewModel.balancesTitle
        totalSectionTitleLabel.text = assetViewModel.totalTitle
        transferableSectionTitleLabel.text = assetViewModel.transferableTitle
        lockedSectionTitleLabel.text = assetViewModel.lockedTitle

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

    private func bind(actionsViewModel: ActionsViewModelProtocol) {
        if let viewModel = actionsViewModel as? WalletActionsViewModelProtocol {
            self.actionsViewModel = viewModel

            sendButton.imageWithTitleView?.title = viewModel.send.title
            sendButton.invalidateLayout()

            receiveButton.imageWithTitleView?.title = viewModel.receive.title
            receiveButton.invalidateLayout()

            buyButton.imageWithTitleView?.title = viewModel.buy.title
            buyButton.invalidateLayout()

            buyButton.isEnabled = (viewModel.buy.command != nil)
        }
    }

    @IBAction private func actionSend() {
        try? actionsViewModel?.send.command.execute()
    }

    @IBAction private func actionReceive() {
        try? actionsViewModel?.receive.command.execute()
    }

    @IBAction private func actionBuy() {
        try? actionsViewModel?.buy.command?.execute()
    }

    @IBAction private func actionFrozen() {
        try? assetViewModel?.infoDetailsCommand.execute()
    }
}
