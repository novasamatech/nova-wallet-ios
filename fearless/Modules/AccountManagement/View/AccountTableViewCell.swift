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
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var infoButton: RoundedButton!

    weak var delegate: AccountTableViewCellDelegate?

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

    func bind(viewModel: ChainAccountViewModelItem) {
        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.address
        mainImageView.image = viewModel.chainIcon

        if let icon = viewModel.accountIcon {
            iconView.bind(icon: icon)
        }
    }

    // MARK: - Actions

    @IBAction private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
