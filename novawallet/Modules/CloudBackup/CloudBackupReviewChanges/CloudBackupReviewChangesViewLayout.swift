import UIKit

final class CloudBackupReviewChangesViewLayout: GenericCollectionViewLayout<MultiValueView> {
    enum Constants {
        static let buttonsHeight: CGFloat = 84
    }

    private let buttonsView: GenericPairValueView<TriangularedButton, TriangularedButton> = .create { view in
        view.makeHorizontal()
        view.spacing = 12
        view.stackView.distribution = .fillEqually

        view.sView.applyDefaultStyle()
        view.fView.applySecondaryDefaultStyle()
    }

    var notNowButton: TriangularedButton {
        buttonsView.fView
    }

    var applyButton: TriangularedButton {
        buttonsView.sView
    }

    convenience init() {
        let defaultSettings = GenericCollectionViewLayoutSettings(
            collectionViewContentInset: UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: Constants.buttonsHeight,
                right: 0
            )
        )

        let headerView: MultiValueView = .create { view in
            view.valueTop.apply(style: .semiboldBodyPrimary)
            view.valueBottom.apply(style: .footnoteSecondary)

            view.spacing = 10
        }

        self.init(header: headerView, settings: defaultSettings)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    private func setupLayout() {
        addSubview(buttonsView)

        buttonsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Constants.buttonsHeight)
        }
    }
}
