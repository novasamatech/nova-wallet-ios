import UIKit

final class ChainAddressDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.alignment = .fill
        return view
    }()

    let networkView = AssetListChainView()

    let addressIconView: DAppIconView = {
        let view = DAppIconView()
        view.contentInsets = ChainAddressDetailsMeasurement.iconContentInsets
        view.backgroundView.cornerRadius = 22.0
        return view
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addAction(for indicator: ChainAddressDetailsIndicator) -> StackActionCell {
        let cell = StackActionCell()

        switch indicator {
        case .navigation:
            cell.rowContentView.disclosureIndicatorView.image = R.image.iconSmallArrow()?.tinted(
                with: R.color.colorTransparentText()!
            )
        case .none:
            cell.rowContentView.disclosureIndicatorView.image = nil
        }

        cell.preferredHeight = 48.0

        cell.borderView.borderType = .none
        cell.contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        containerView.stackView.addArrangedSubview(cell)

        return cell
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let networkContainerView = UIView()
        networkContainerView.backgroundColor = .clear

        containerView.stackView.addArrangedSubview(networkContainerView)
        networkContainerView.addSubview(networkView)
        networkView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.height.equalTo(ChainAddressDetailsMeasurement.networkHeight)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
        }

        containerView.stackView.setCustomSpacing(ChainAddressDetailsMeasurement.headerSpacing, after: networkContainerView)

        let addressContainerView = UIView()
        addressContainerView.backgroundColor = .clear
        containerView.stackView.addArrangedSubview(addressContainerView)

        addressContainerView.addSubview(addressIconView)
        addressIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(ChainAddressDetailsMeasurement.iconViewSize)
            make.top.equalToSuperview()
        }

        addressContainerView.addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(addressIconView.snp.bottom).offset(ChainAddressDetailsMeasurement.headerSpacing)
            make.bottom.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(
            ChainAddressDetailsMeasurement.headerBottomInset,
            after: addressContainerView
        )
    }
}
