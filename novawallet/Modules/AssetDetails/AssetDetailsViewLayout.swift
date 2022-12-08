import UIKit
import SoraUI
import SnapKit

final class AssetDetailsViewLayout: UIView {
    let backgroundView = MultigradientView.background
    let chainView = AssetListChainView()

    let assetIconView: AssetIconView = .create {
        $0.backgroundView.cornerRadius = 14
        $0.backgroundView.apply(style: .container)
        $0.contentInsets = .init(top: 3, left: 3, bottom: 3, right: 3)
        $0.imageView.tintColor = R.color.colorIconSecondary()
    }

    let assetLabel = UILabel(
        style: .init(
            textColor: R.color.colorTextPrimary(),
            font: .semiBoldBody
        ),
        textAlignment: .right
    )
    let priceLabel = UILabel(style: .footnoteSecondary)
    let priceChangeLabel = UILabel(style: .init(textColor: .clear, font: .regularFootnote))

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 6, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

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
        $0.imageWithTitleView?.iconImage = R.image.iconSend()
    }

    let receiveButton: RoundedButton = .create {
        $0.apply(style: .operation)
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        $0.contentOpacityWhenDisabled = 0.2
        $0.changesContentOpacityWhenHighlighted = true
        $0.imageWithTitleView?.layoutType = .verticalImageFirst
        $0.isEnabled = false
        $0.imageWithTitleView?.iconImage = R.image.iconReceive()
    }

    let buyButton: RoundedButton = .create {
        $0.apply(style: .operation)
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        $0.contentOpacityWhenDisabled = 0.2
        $0.changesContentOpacityWhenHighlighted = true
        $0.imageWithTitleView?.layoutType = .verticalImageFirst
        $0.isEnabled = false
        $0.imageWithTitleView?.iconImage = R.image.iconBuy()
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
        balanceTableView.addArrangedSubview(headerCell)
        balanceTableView.addArrangedSubview(totalCell)
        balanceTableView.addArrangedSubview(transferrableCell)
        balanceTableView.addArrangedSubview(lockCell)

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        let priceStack = UIStackView(arrangedSubviews: [priceLabel, priceChangeLabel])
        priceStack.spacing = 4

        addSubview(priceStack)
        priceStack.snp.makeConstraints {
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.equalTo(26)
            $0.top.equalTo(self.safeAreaLayoutGuide.snp.top)
        }

        let assetView = UIStackView(arrangedSubviews: [assetIconView, assetLabel])
        assetView.spacing = 8
        addSubview(assetView)
        assetView.snp.makeConstraints {
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.equalTo(28)
            $0.bottom.equalTo(priceStack.snp.top).offset(-7)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(priceStack.snp.bottom)
        }

        containerView.stackView.spacing = 8
        containerView.stackView.addArrangedSubview(balanceTableView)
        containerView.stackView.addArrangedSubview(buttonsRow)
    }

    func set(locale: Locale) {
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

    func set(assetDetailsModel: AssetDetailsModel) {
        assetDetailsModel.assetIcon?.cancel(on: assetIconView.imageView)
        assetIconView.imageView.image = nil

        let iconSize = 28 - 6
        assetDetailsModel.assetIcon?.loadImage(
            on: assetIconView.imageView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )
        assetLabel.text = assetDetailsModel.tokenName
        chainView.bind(viewModel: assetDetailsModel.network)

        guard let priceModel = assetDetailsModel.price else {
            priceChangeLabel.text = ""
            priceLabel.text = ""
            return
        }

        priceLabel.text = priceModel.amount

        switch priceModel.change {
        case let .increase(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorTextPositive()
        case let .decrease(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorTextNegative()
        }
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
        isUserInteractionEnabled = true
        rowContentView.isUserInteractionEnabled = true
        rowContentView.distribution = .fillEqually
        rowContentView.axis = .horizontal
        backgroundColor = .clear

        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView.cornerRadius = 12
        roundedBackgroundView.roundingCorners = .allCorners
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

struct AssetDetailsModel {
    let tokenName: String
    let assetIcon: ImageViewModelProtocol?
    let price: AssetPriceViewModel?
    let network: NetworkViewModel
}
