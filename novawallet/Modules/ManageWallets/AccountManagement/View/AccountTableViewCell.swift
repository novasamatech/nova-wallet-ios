import UIKit
import SubstrateSdk
import UIKit_iOS

protocol AccountTableViewCellDelegate: AnyObject {
    func didSelectInfo(_ cell: AccountTableViewCell)
}

final class AccountTableViewCell: UITableViewCell {
    private enum Constants {
        static let actionButtonWidth: CGFloat = 40.0
    }

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var mainImageView: UIImageView!
    @IBOutlet private var warningImageView: UIImageView!
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var infoButton: RoundedButton!
    @IBOutlet private var infoButtonWidth: NSLayoutConstraint!

    weak var delegate: AccountTableViewCellDelegate?
    private var viewModel: ChainAccountViewModelItem?

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellBackgroundPressed()
        self.selectedBackgroundView = selectedBackgroundView

        iconView.fillColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = CGRect(origin: .zero, size: bounds.size)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.chainIconViewModel?.cancel(on: mainImageView)
    }

    func setAccessoryActionEnabled(_ enabled: Bool) {
        infoButton.isUserInteractionEnabled = enabled
    }

    func bind(viewModel: ChainAccountViewModelItem) {
        self.viewModel?.chainIconViewModel?.cancel(on: mainImageView)
        mainImageView.image = nil

        self.viewModel = viewModel

        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.address ?? viewModel.warning ?? ""

        if viewModel.address != nil {
            detailsLabel.lineBreakMode = .byTruncatingMiddle
        } else {
            detailsLabel.lineBreakMode = .byTruncatingTail
        }

        viewModel.chainIconViewModel?.loadImage(
            on: mainImageView,
            targetSize: CGSize(width: 32.0, height: 32.0),
            animated: true
        )

        if let icon = viewModel.accountIcon {
            iconView.bind(icon: icon)

            iconView.isHidden = false
            warningImageView.isHidden = true
        } else {
            iconView.isHidden = true
            warningImageView.isHidden = false
        }

        if viewModel.hasAction {
            selectionStyle = .default

            infoButton.imageWithTitleView?.iconImage = R.image.iconMore()?.tinted(
                with: R.color.colorIconSecondary()!
            )

            infoButtonWidth.constant = Constants.actionButtonWidth
        } else {
            selectionStyle = .none

            infoButton.imageWithTitleView?.iconImage = nil

            infoButtonWidth.constant = 0.0
        }

        setNeedsLayout()
    }

    // MARK: - Actions

    @IBAction private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
