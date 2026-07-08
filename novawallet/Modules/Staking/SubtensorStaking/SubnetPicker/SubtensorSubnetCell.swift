import UIKit

/// Table cell showing a single subnet row: name, netuid, TAO reserve, spot price.
final class SubtensorSubnetCell: UITableViewCell {
    static let reuseId = "SubtensorSubnetCell"

    private let containerView: UIView = {
        let container = UIView()
        container.backgroundColor = R.color.colorBlockBackground()
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        return container
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let netuidLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    private let taoReserveLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .right
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .right
        return label
    }()

    private let disclosureIcon: UIImageView = {
        let iv = UIImageView(image: R.image.iconSmallArrow()?.withRenderingMode(.alwaysTemplate))
        iv.tintColor = R.color.colorIconSecondary()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        let leftStack = UIStackView(arrangedSubviews: [nameLabel, netuidLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2

        let rightStack = UIStackView(arrangedSubviews: [taoReserveLabel, priceLabel])
        rightStack.axis = .vertical
        rightStack.spacing = 2
        rightStack.alignment = .trailing

        let mainStack = UIStackView(arrangedSubviews: [leftStack, rightStack, disclosureIcon])
        mainStack.axis = .horizontal
        mainStack.spacing = 8
        mainStack.alignment = .center

        disclosureIcon.snp.makeConstraints { $0.size.equalTo(CGSize(width: 16, height: 16)) }

        containerView.addSubview(mainStack)
        mainStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 12))
        }
    }

    func bind(subnet: SubtensorSubnetInfo) {
        let displayName = subnet.name ?? "Subnet \(subnet.netuid)"
        nameLabel.text = displayName
        netuidLabel.text = "SN\(subnet.netuid)"

        let taoReserveFormatted = String(format: "%.0f TAO", Double(subnet.taoReserve) / 1e9)
        taoReserveLabel.text = taoReserveFormatted

        let spotPrice = subnet.spotPrice
        if spotPrice > 0 {
            priceLabel.text = String(format: "%.4f TAO/α", spotPrice)
        } else {
            priceLabel.text = "—"
        }
    }
}
