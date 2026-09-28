import Foundation
import SubstrateSdk
import UIKit
import UIKit_iOS

final class SubtensorValidatorInfoViewController: UIViewController {
    private let detail: SubtensorValidatorDetail
    private let apy: String?
    private let locale: Locale
    private let chainAsset: ChainAsset
    private let price: Balance?
    private let container = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
    private let iconGenerator = PolkadotIconGenerator()

    init(detail: SubtensorValidatorDetail, apy: String?, locale: Locale, chainAsset: ChainAsset, price: Balance?) {
        self.detail = detail
        self.apy = apy
        self.locale = locale
        self.chainAsset = chainAsset
        self.price = price
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        title = strings.stakingSubtensorUiValidatorInfoTitle()
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        container.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        container.stackView.isLayoutMarginsRelativeArrangement = true
        container.stackView.alignment = .fill
        container.stackView.spacing = 8
        view.addSubview(container)
        container.snp.makeConstraints { make in make.edges.equalToSuperview() }

        let item = detail.item
        let address = (try? item.hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? "—"
        let name = detail.identity?.name ?? item.name ?? address
        let header = makeCard(insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12
        let icon: PolkadotIconView = .create { view in
            view.backgroundColor = .clear
            view.fillColor = .clear
        }
        if let drawable = try? iconGenerator.generateFromAccountId(item.hotkey) {
            icon.bind(icon: drawable)
        }
        icon.snp.makeConstraints { make in make.size.equalTo(40) }
        header.addArrangedSubview(icon)
        let nameStack = UIStackView()
        nameStack.axis = .vertical
        nameStack.spacing = 2
        addText(name, to: nameStack, emphasized: true)
        let shortAddress = address == "—" ? address : String(address.prefix(7)) + "…" + String(address.suffix(5))
        addText(shortAddress, to: nameStack, emphasized: false)
        header.addArrangedSubview(nameStack)
        container.stackView.addArrangedSubview(header)
        container.stackView.setCustomSpacing(24, after: header)

        addSectionTitle(strings.stakingSubtensorUiValidatorInfoStaking())
        let staking = makeCard(insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
        let active = item.netuid == SubtensorStakingPallet.rootNetuid
            ? item.status != nil
            : item.status?.isActive == true && item.status?.hasPermit == true
        addRow(
            strings.stakingSubtensorUiValidatorInfoStatus(),
            active
                ? strings.stakingSubtensorUiValidatorInfoActive()
                : strings.stakingSubtensorUiValidatorInfoUnavailable(),
            to: staking,
            positive: active
        )
        var stakedValue = "—"
        if let alpha = item.hotkeyAlpha,
           let price,
           let amount = Decimal.fromSubstrateAmount(
               alpha * price / SubtensorStakingPallet.alphaPriceScale,
               precision: chainAsset.assetDisplayInfo.assetPrecision
           ) {
            stakedValue = "\(format(amount)) TAO"
        }
        addRow(strings.stakingSubtensorUiValidatorInfoStaked(), stakedValue, to: staking, info: true)
        let takeValue = item.take.map { "\(format($0 * 100))%" } ?? "—"
        addRow(strings.stakingSubtensorUiValidatorInfoTake(), takeValue, to: staking, info: true)
        addRow(strings.stakingSubtensorUiValidatorInfoSubnets(), "—", to: staking)
        addRow(strings.stakingSubtensorUiValidatorInfoReward(), apy ?? "—", to: staking, positive: apy != nil)
        if let divider = staking.arrangedSubviews.last {
            staking.removeArrangedSubview(divider)
            divider.removeFromSuperview()
        }
        container.stackView.addArrangedSubview(staking)
        container.stackView.setCustomSpacing(24, after: staking)

        setupIdentity()
    }

    private func setupIdentity() {
        if let website = detail.identity?.url, !website.isEmpty {
            let strings = R.string(preferredLanguages: locale.rLanguages).localizable
            addSectionTitle(strings.stakingSubtensorUiValidatorInfoIdentity())
            let identity = makeCard(insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            let button = UIButton(type: .system)
            button.setTitle(website, for: .normal)
            button.contentHorizontalAlignment = .right
            button.titleLabel?.font = .regularFootnote
            button.titleLabel?.lineBreakMode = .byTruncatingMiddle
            button.addAction(UIAction { _ in
                guard let url = URL(string: website), UIApplication.shared.canOpenURL(url) else { return }
                UIApplication.shared.open(url)
            }, for: .touchUpInside)
            let webLabel = UILabel()
            webLabel.text = strings.stakingSubtensorUiValidatorInfoWeb()
            webLabel.font = .regularFootnote
            webLabel.textColor = R.color.colorTextSecondary()
            let row = UIStackView(arrangedSubviews: [webLabel, button])
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center
            row.snp.makeConstraints { make in make.height.equalTo(44) }
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            identity.addArrangedSubview(row)
            container.stackView.addArrangedSubview(identity)
        }
    }

    private func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? value.description
    }

    private func makeCard(insets: UIEdgeInsets) -> UIStackView {
        let card = UIStackView()
        card.axis = .vertical
        card.alignment = .fill
        card.spacing = 0
        card.backgroundColor = R.color.colorBlockBackground()
        card.layer.cornerRadius = 12
        card.layoutMargins = insets
        card.isLayoutMarginsRelativeArrangement = true
        return card
    }

    private func addText(_ text: String, to card: UIStackView, emphasized: Bool) {
        let label = UILabel()
        label.text = text
        label.font = emphasized ? .semiBoldSubheadline : .caption1
        label.textColor = emphasized ? R.color.colorTextPrimary() : R.color.colorTextSecondary()
        label.lineBreakMode = .byTruncatingTail
        card.addArrangedSubview(label)
    }

    private func addSectionTitle(_ title: String) {
        let label = UILabel()
        label.text = title.uppercased(with: locale)
        label.font = .semiBoldCaps1
        label.textColor = R.color.colorTextSecondary()
        container.stackView.addArrangedSubview(label)
    }

    private func addRow(
        _ title: String,
        _ value: String,
        to card: UIStackView,
        positive: Bool = false,
        info: Bool = false
    ) {
        let left = UILabel()
        left.text = title
        left.font = .regularFootnote
        left.textColor = R.color.colorTextSecondary()
        let titleStack = UIStackView(arrangedSubviews: [left])
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 4
        if info {
            let icon = UIImageView(image: R.image.iconInfoFilled())
            icon.tintColor = R.color.colorIconSecondary()
            icon.snp.makeConstraints { make in make.size.equalTo(16) }
            titleStack.addArrangedSubview(icon)
        }
        let right = UILabel()
        right.text = value
        right.font = .regularFootnote
        right.textColor = positive ? R.color.colorTextPositive() : R.color.colorTextPrimary()
        right.textAlignment = .right
        right.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [titleStack, right])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.snp.makeConstraints { make in make.height.equalTo(44) }
        card.addArrangedSubview(row)
        let divider = UIView()
        divider.backgroundColor = R.color.colorDivider()
        divider.snp.makeConstraints { make in make.height.equalTo(0.5) }
        card.addArrangedSubview(divider)
    }
}
