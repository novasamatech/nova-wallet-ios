import UIKit
import UIKit_iOS
import Foundation_iOS

class YourValidatorListStatusSectionView: YourValidatorListDescSectionView {
    let statusView: IconDetailsView = {
        let view = IconDetailsView()
        view.detailsLabel.font = .semiBoldBody
        view.detailsLabel.textColor = R.color.colorTextPrimary()
        view.detailsLabel.numberOfLines = 0
        view.mode = .iconDetails
        view.spacing = 8.0
        return view
    }()

    override func setupLayout() {
        super.setupLayout()

        mainStackView.insertArranged(view: statusView, before: descriptionLabel)

        statusView.snp.makeConstraints { make in
            make.height.equalTo(20.0)
        }

        mainStackView.setCustomSpacing(8, after: statusView)
    }

    func bind(icon: UIImage, title: String) {
        statusView.imageView.image = icon
        statusView.detailsLabel.text = title
    }
}
