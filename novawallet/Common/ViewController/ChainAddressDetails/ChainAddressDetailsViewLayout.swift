import UIKit

final class ChainAddressDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.alignment = .fill
        return view
    }()

    private var titleView: UIView?

    let addressIconView: DAppIconView = {
        let view = DAppIconView()
        view.contentInsets = ChainAddressDetailsMeasurement.iconContentInsets
        view.backgroundView.cornerRadius = 22.0
        return view
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle(with titleViewModel: ChainAddressDetailsViewModel.Title, locale: Locale) {
        switch titleViewModel {
        case let .network(network):
            setupNetworkTitleView(for: network)
        case let .text(textResource):
            setupTextTitleView(for: textResource.value(for: locale))
        }
    }

    func addAction(for indicator: ChainAddressDetailsIndicator) -> StackActionCell {
        let cell = StackActionCell()

        switch indicator {
        case .navigation:
            cell.rowContentView.disclosureIndicatorView.image = R.image.iconSmallArrow()?.tinted(
                with: R.color.colorIconSecondary()!
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
}

private extension ChainAddressDetailsViewLayout {
    func setupNetworkTitleView(for viewModel: NetworkViewModel) {
        let networkView = AssetListChainView()

        setupTitleView(networkView, with: ChainAddressDetailsMeasurement.textTitleHeight)

        networkView.bind(viewModel: viewModel)
    }

    func setupTextTitleView(for text: String) {
        let titleView: BorderedLabelView = .create { view in
            view.apply(style: .chipsText)
        }

        setupTitleView(titleView, with: ChainAddressDetailsMeasurement.networkTitleHeight)

        titleView.titleLabel.text = text
    }

    func setupTitleView(_ titleView: UIView, with height: CGFloat) {
        self.titleView?.removeFromSuperview()

        let titleContainerView = UIView()
        titleContainerView.backgroundColor = .clear

        containerView.stackView.insertArrangedSubview(titleContainerView, at: 0)
        titleContainerView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.height.equalTo(height)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
        }

        containerView.stackView.setCustomSpacing(
            ChainAddressDetailsMeasurement.headerSpacing,
            after: titleContainerView
        )

        self.titleView = titleView
    }

    func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

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
