import UIKit
import SoraUI

final class ProfileTableViewCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(viewModel: SettingsCellViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.accessoryTitle
    }
}
