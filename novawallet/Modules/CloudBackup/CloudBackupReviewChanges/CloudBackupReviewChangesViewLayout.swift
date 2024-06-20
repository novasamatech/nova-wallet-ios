import UIKit

final class CloudBackupReviewChangesViewLayout: GenericCollectionViewLayout<MultiValueView> {
    enum Constants {
        static let settings = GenericCollectionViewLayoutSettings(
            estimatedHeaderHeight: 90,
            collectionViewContentInset: UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: 84,
                right: 0
            )
        )
    }

    private let buttonsView: GenericPairValueView<TriangularedButton, TriangularedButton> = .create { view in
        view.makeHorizontal()
        view.spacing = 12
        view.stackView.distribution = .fillEqually

        view.sView.applyDefaultStyle()
        view.fView.applySecondaryDefaultStyle()
        
        view.backgroundColor = R.color.colorBottomSheetBackground()
    }

    var notNowButton: TriangularedButton {
        buttonsView.fView
    }

    var applyButton: TriangularedButton {
        buttonsView.sView
    }

    convenience init() {
        let headerView: MultiValueView = .create { view in
            view.valueTop.textAlignment = .left
            view.valueTop.apply(style: .semiboldBodyPrimary)

            view.valueBottom.textAlignment = .left
            view.valueBottom.apply(style: .footnoteSecondary)
            view.valueBottom.numberOfLines = 0

            view.spacing = 10
        }

        self.init(header: headerView, settings: Constants.settings)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    private func setupLayout() {
        addSubview(buttonsView)

        buttonsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-16)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

extension CloudBackupReviewChangesViewLayout {
    static func estimateHeight(for sections: Int, items: Int) -> CGFloat {
        let settings = Constants.settings
        let itemHeight = settings.estimatedRowHeight

        let sectionsHeight = settings.estimatedSectionHeaderHeight +
            settings.sectionContentInsets.top +
            settings.sectionContentInsets.bottom

        let estimatedListHeight = settings.collectionViewContentInset.top +
            CGFloat(items) * itemHeight +
            CGFloat(sections) * sectionsHeight +
            settings.collectionViewContentInset.bottom

        return settings.estimatedHeaderHeight + estimatedListHeight
    }
}
