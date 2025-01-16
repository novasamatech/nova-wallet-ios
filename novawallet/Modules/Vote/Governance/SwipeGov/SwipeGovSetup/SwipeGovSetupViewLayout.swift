import UIKit
import UIKit_iOS

final class SwipeGovSetupViewLayout: BaseReferendumVoteSetupViewLayout {
    let detailsLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlineSecondary)
        view.textAlignment = .left
        view.numberOfLines = 0
    }

    let continueButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    override func setupButtonsLayout() {
        buttonContainer.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.top.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    override func setupLayout() {
        super.setupLayout()

        containerView.stackView.insertArranged(view: detailsLabel, after: titleLabel)

        containerView.stackView.setCustomSpacing(8.0, after: titleLabel)
        containerView.stackView.setCustomSpacing(12.0, after: detailsLabel)

        setupContentWidth()
    }
}
