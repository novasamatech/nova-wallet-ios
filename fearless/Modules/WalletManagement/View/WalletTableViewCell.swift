import UIKit
import FearlessUtils
import SoraUI

protocol WalletTableViewCellDelegate: AnyObject {
    func didSelectInfo(_ cell: WalletTableViewCell)
}

final class WalletTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var infoButton: RoundedButton!
    @IBOutlet private var selectionImageView: UIImageView!

    weak var delegate: WalletTableViewCellDelegate?

    func setReordering(_ reordering: Bool, animated: Bool) {
        let closure = {
            self.infoButton.alpha = reordering ? 0.0 : 1.0
        }

        if animated {
            BlockViewAnimator().animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReorderControl(R.color.colorWhite()!)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView

        showsReorderControl = false
    }

    func bind(viewModel: ManagedWalletViewModelItem) {
        titleLabel.text = viewModel.name

        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        selectionImageView.isHidden = !viewModel.isSelected
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = CGRect(origin: .zero, size: bounds.size)
    }

    // MARK: Private

    @IBAction private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
