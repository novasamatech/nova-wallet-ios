import UIKit

final class SubtensorOperationResultViewLayout: ScrollableContainerLayoutView {
    let backButton: UIButton = .create { button in
        button.setImage(R.image.iconBack()?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = R.color.colorIconPrimary()
    }

    let statusView = SubtensorOperationStatusView()

    let pairsView: SwapPairView = .create { view in
        view.leftAssetView.hidesHub = true
        view.rigthAssetView.hidesHub = true
    }

    let detailsView: SubtensorOperationResultDetailsView = .create { view in
        view.contentInsets = .zero
        view.setExpanded(false, animated: false)
    }

    private(set) var actionButton: TriangularedButton?

    func setupActionButton(title: String) -> TriangularedButton {
        removeActionButton()

        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.imageWithTitleView?.title = title

        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + 8

        actionButton = button

        return button
    }

    func removeActionButton() {
        actionButton?.removeFromSuperview()
        actionButton = nil
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = UIEdgeInsets(top: 76, left: 16, bottom: 0, right: 16)

        addArrangedSubview(statusView, spacingAfter: 24)
        addArrangedSubview(pairsView, spacingAfter: 24)
        addArrangedSubview(detailsView)

        addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(8)
            make.top.equalTo(safeAreaLayoutGuide).inset(8)
            make.size.equalTo(44)
        }
    }
}
