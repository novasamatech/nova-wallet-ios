import UIKit
import SoraUI

final class WalletManageTableViewCell: WalletsListTableViewCell {
    private lazy var reorderingAnimator = BlockViewAnimator()

    let disclosureIndicatorView: UIImageView = {
        let imageView = UIImageView()
        let icon = R.image.iconSmallArrow()?.tinted(with: R.color.colorTransparentText()!)
        imageView.image = icon
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return imageView
    }()

    func setReordering(_ reordering: Bool, animated: Bool) {
        let closure = {
            self.disclosureIndicatorView.alpha = reordering ? 0.0 : 1.0
        }

        if animated {
            reorderingAnimator.animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReorderControl(R.color.colorWhite()!)
        }
    }

    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(disclosureIndicatorView)
        disclosureIndicatorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.leading.equalTo(infoView.snp.trailing).offset(8.0)
        }
    }
}
