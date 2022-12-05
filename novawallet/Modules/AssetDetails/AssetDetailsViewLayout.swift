import UIKit
import SoraUI

final class AssetDetailsViewLayout: UIView {
    private let preferredRowHeight: CGFloat = 48

    let headerCell: StackTableHeaderCell = .create {
        $0.titleLabel.apply(style: .regularSubhedlineSecondary)
        $0.contentInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
    }

    let totalCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
    }

    let transferrableCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
    }

    let lockCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
    }

    let sendButton: RoundedButton = .create {
        $0.apply(style: .operation)
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        $0.contentOpacityWhenDisabled = 0.2
        $0.changesContentOpacityWhenHighlighted = true
        $0.imageWithTitleView?.layoutType = .verticalImageFirst
        $0.isEnabled = false
    }

    let receiveButton: RoundedButton = .create {
        $0.apply(style: .operation)
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        $0.contentOpacityWhenDisabled = 0.2
        $0.changesContentOpacityWhenHighlighted = true
        $0.imageWithTitleView?.layoutType = .verticalImageFirst
        $0.isEnabled = false
    }

    let buyButton: RoundedButton = .create {
        $0.apply(style: .operation)
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        $0.contentOpacityWhenDisabled = 0.2
        $0.changesContentOpacityWhenHighlighted = true
        $0.imageWithTitleView?.layoutType = .verticalImageFirst
        $0.isEnabled = false
    }

    private lazy var buttonsRow = PayButtonsRow(
        frame: .zero,
        views: [sendButton, receiveButton, buyButton]
    )

    private let balanceTableView: StackTableView = .create {
        $0.cellHeight = 48
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        balanceTableView.addArrangedSubview(totalCell)
        balanceTableView.addArrangedSubview(transferrableCell)
        balanceTableView.addArrangedSubview(lockCell)
    }

    private func set(locale: Locale) {
        let languages = locale.rLanguages

        headerCell.titleLabel.text = R.string.localizable.walletBalancesWidgetTitle(
            preferredLanguages: languages
        )
        totalCell.titleLabel.text = R.string.localizable.walletTransferTotalTitle(
            preferredLanguages: languages
        )
        transferrableCell.titleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: languages
        )
        lockCell.titleLabel.text = R.string.localizable.walletBalanceLocked(
            preferredLanguages: languages
        )
        sendButton.imageWithTitleView?.title = R.string.localizable.walletSendTitle(
            preferredLanguages: languages
        )
        sendButton.invalidateLayout()

        receiveButton.imageWithTitleView?.title = R.string.localizable.walletAssetReceive(
            preferredLanguages: languages
        )
        receiveButton.invalidateLayout()

        buyButton.imageWithTitleView?.title = R.string.localizable.walletAssetBuy(
            preferredLanguages: languages
        )
        buyButton.invalidateLayout()
    }
}

final class PayButtonsRow: RowView<UIStackView>, StackTableViewCellProtocol {
    init(frame: CGRect, views: [UIView]) {
        super.init(frame: frame)

        configureStyle()
        views.forEach(rowContentView.addArrangedSubview)
    }

    private func configureStyle() {
        preferredHeight = 80
        borderView.strokeColor = R.color.colorDivider()!
        isUserInteractionEnabled = false
        rowContentView.distribution = .fillEqually
        rowContentView.axis = .horizontal
    }
}

extension StackTitleMultiValueCell {
    func bind(viewModel: BalanceViewModelProtocol) {
        rowContentView.valueView.bind(
            topValue: viewModel.amount,
            bottomValue: viewModel.price
        )
    }
}

extension StackTitleMultiValueCell {
    struct Style {
        let title: IconDetailsView.Style
        let value: MultiValueView.Style
    }

    func apply(style: Style) {
        rowContentView.titleView.apply(style: style.title)
        rowContentView.valueView.apply(style: style.value)
    }
}

extension StackTitleMultiValueCell.Style {
    static let balancePart = StackTitleMultiValueCell.Style(
        title: .secondaryRow,
        value: .bigRowContrasted
    )
}

extension IconDetailsView.Style {
    static let secondaryRow = IconDetailsView.Style(
        tintColor: R.color.colorTextSecondary()!,
        font: .regularSubheadline
    )
}

extension RoundedButton {
    struct Style {
        let background: RoundedView.Style
        let title: UILabel.Style
    }

    func apply(style: Style) {
        roundedBackgroundView?.apply(style: style.background)
        imageWithTitleView?.titleFont = style.title.font
        imageWithTitleView?.titleColor = style.title.textColor
    }
}

extension RoundedButton.Style {
    static let operation = RoundedButton.Style(
        background: .icon,
        title: .init(
            textColor: R.color.colorTextPrimary()!,
            font: .semiBoldFootnote
        )
    )
}

extension RoundedView.Style {
    static let icon = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 0, corners: .allCorners)
    )
}
