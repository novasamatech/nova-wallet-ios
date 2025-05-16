import UIKit

final class PayShopAvailabilityContentView: UIView {
    let logoView: GradientIconDetailsView = .create { view in
        view.bind(gradient: .polkadotPay)
        view.backgroundView.cornerRadius = 8
        view.contentInsets = UIEdgeInsets(verticalInset: 4, horizontalInset: 6)
        view.titleView.spacing = 6
        view.titleView.imageView.image = R.image.iconPolkadot()
        view.titleView.detailsLabel.apply(style: .semiboldCaps1Primary)
    }

    let cashbackLabel: UILabel = .create { label in
        label.apply(style: .boldTitle1Primary)
        label.numberOfLines = 0
        label.textAlignment = .center
    }

    let detailsLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
        label.numberOfLines = 0
        label.textAlignment = .center
    }

    var locale: Locale? {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: PayShopAvailabilityViewModel) {
        switch viewModel {
        case let .available(state):
            applyState(state)
        case .unsupported:
            // TODO: Switch style here for unsupported state
            break
        }
    }

    private func applyState(_ state: PayShopAvailabilityViewModel.Available) {
        switch state {
        case let .loaded(cashback):
            cashbackLabel.text = R.string.localizable.shopMerchantsCashbackFormat(cashback)
        case .loading:
            break
        case .error:
            cashbackLabel.text = ""
        }
    }

    private func applyLocalization() {
        logoView.titleView.detailsLabel.text = R.string.localizable.commonPolkadotPay(
            preferredLanguages: locale?.rLanguages
        ).uppercased()

        detailsLabel.text = R.string.localizable.shopMerchantsAvailabilityTitle(
            preferredLanguages: locale?.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(logoView)

        logoView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.centerX.top.equalToSuperview()
        }

        addSubview(cashbackLabel)

        cashbackLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(logoView.snp.bottom).offset(8)
        }

        addSubview(detailsLabel)

        detailsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(cashbackLabel.snp.bottom)
            make.top.greaterThanOrEqualTo(logoView.snp.bottom).offset(45)
            make.bottom.equalToSuperview()
        }
    }
}

typealias PayShopAvailabilityCell = CollectionViewContainerCell<PayShopAvailabilityContentView>
