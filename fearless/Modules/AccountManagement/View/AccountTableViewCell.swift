import UIKit
import FearlessUtils
import SoraUI

protocol AccountTableViewCellDelegate: AnyObject {
    func didSelectInfo(_ cell: AccountTableViewCell)
}

final class AccountTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var mainImageView: UIImageView!
    @IBOutlet private var warningImageView: UIImageView!
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var infoButton: RoundedButton!

    weak var delegate: AccountTableViewCellDelegate?
    private var viewModel: ChainAccountViewModelItem?

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = CGRect(origin: .zero, size: bounds.size)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.chainIconViewModel?.cancel(on: mainImageView)
    }

    func bind(viewModel: ChainAccountViewModelItem) {
        self.viewModel?.chainIconViewModel?.cancel(on: mainImageView)
        mainImageView.image = nil

        self.viewModel = viewModel

        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.address ?? viewModel.warning ?? ""

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
    }

    // MARK: - Actions

    @IBAction private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
