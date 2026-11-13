import UIKit
import UIKit_iOS

final class SwapSetupAssetHeaderView: UIView {
    let titleView = SwapSetupTitleView(frame: .zero)

    let actionButton: RoundedButton = .create {
        $0.applyPrimaryStyle()
        $0.isHidden = true
    }

    var maxButton: SwapSetupTitleButton { titleView.button }

    private var model: TitleHorizontalMultiValueView.Model?
    private var balanceTitle: String?
    private var isBalanceOnly: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.height)
    }

    func bind(model: TitleHorizontalMultiValueView.Model) {
        self.model = model

        applyModel()
    }

    func bindBalance(model: TitleHorizontalMultiValueView.Model) {
        isBalanceOnly = true

        bind(model: model)
    }

    func setAction(title: String?, balanceTitle: String) {
        actionButton.imageWithTitleView?.title = title
        actionButton.invalidateLayout()

        self.balanceTitle = balanceTitle
    }

    func setActionVisible(_ isVisible: Bool) {
        guard actionButton.isHidden == isVisible else {
            return
        }

        actionButton.isHidden = !isVisible

        applyModel()
    }
}

// MARK: Private

private extension SwapSetupAssetHeaderView {
    func setupLayout() {
        let stackView = UIView.hStack(
            alignment: .center,
            distribution: .fill,
            spacing: Constants.actionSpacing,
            margins: Constants.contentInsets,
            [titleView, actionButton]
        )

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(Constants.actionHeight)
        }

        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let buttonInsets = maxButton.contentInsets
        maxButton.preferredHeight = titleView.buttonValue.font.lineHeight + buttonInsets.top + buttonInsets.bottom
    }

    func applyModel() {
        guard let model else {
            return
        }

        let showsBalance = isBalanceOnly || !actionButton.isHidden

        if showsBalance, !isBalanceOnly, let balanceTitle {
            titleView.bind(model: .init(title: model.title, subtitle: balanceTitle, value: model.value))
        } else {
            titleView.bind(model: model)
        }

        titleView.buttonTitle.apply(style: showsBalance ? .footnoteSecondary : .footnoteAccentText)
        titleView.buttonValue.apply(style: showsBalance ? .footnoteSecondary : .footnotePrimary)
        maxButton.isUserInteractionEnabled = !showsBalance
    }
}

extension SwapSetupAssetHeaderView {
    enum Constants {
        static let height: CGFloat = 32
        static let contentInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        static let actionHeight: CGFloat = 32
        static let actionSpacing: CGFloat = 8
    }
}
