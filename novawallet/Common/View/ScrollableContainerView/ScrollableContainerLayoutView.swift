import UIKit

class ScrollableContainerLayoutView: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    var stackView: UIStackView { containerView.stackView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
        }
    }

    func addArrangedSubview(_ view: UIView, spacingAfter value: CGFloat = 0) {
        stackView.addArrangedSubview(view)

        if value > 0 {
            stackView.setCustomSpacing(value, after: view)
        }
    }

    func insertArrangedSubview(_ view: UIView, after oldView: UIView, spacingAfter value: CGFloat = 0) {
        stackView.insertArranged(view: view, after: oldView)

        if value > 0 {
            stackView.setCustomSpacing(value, after: view)
        }
    }

    func applyWarning(
        on warningView: inout InlineAlertView?,
        after view: UIView?,
        text: String?,
        spacing: CGFloat = 0
    ) {
        if let text = text {
            if warningView == nil {
                let newView = InlineAlertView.warning()

                if let afterView = view {
                    insertArrangedSubview(newView, after: afterView, spacingAfter: spacing)
                } else {
                    addArrangedSubview(newView, spacingAfter: spacing)
                }

                warningView = newView
            }

            warningView?.contentView.detailsLabel.text = text
        } else {
            warningView?.removeFromSuperview()
            warningView = nil
        }

        setNeedsLayout()
    }
}

class SCGenericActionLayoutView<A: UIView>: ScrollableContainerLayoutView {
    let genericActionView = A()

    override func setupLayout() {
        addSubview(genericActionView)
        genericActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(genericActionView.snp.top).offset(-8.0)
        }
    }
}

typealias SCLoadableActionLayoutView = SCGenericActionLayoutView<LoadableActionView>

typealias SCSingleActionLayoutView = SCGenericActionLayoutView<TriangularedButton>
