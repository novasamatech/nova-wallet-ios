import UIKit
import SoraUI
import SnapKit

final class AssetDetailsViewLayout: UIView {
    let backgroundView = MultigradientView.background
    let chainView = AssetListChainView()
    let topBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

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

    let sendButton: RoundedButton = createOperationButton(icon: R.image.iconSend())
    let receiveButton: RoundedButton = createOperationButton(icon: R.image.iconReceive())
    let buyButton: RoundedButton = createOperationButton(icon: R.image.iconBuy())

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

    private static func createOperationButton(icon: UIImage?) -> RoundedButton {
        let button = RoundedButton()
        button.apply(style: .operation)
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        button.contentOpacityWhenDisabled = 0.2
        button.changesContentOpacityWhenHighlighted = true
        button.imageWithTitleView?.layoutType = .verticalImageFirst
        button.isEnabled = false
        button.imageWithTitleView?.iconImage = icon
        return button
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

        addSubview(topBackgroundView)
        topBackgroundView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(priceStack.snp.bottom)
        }

        priceStack.bringSubviewToFront(topBackgroundView)

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

        let iconSize = 22
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
