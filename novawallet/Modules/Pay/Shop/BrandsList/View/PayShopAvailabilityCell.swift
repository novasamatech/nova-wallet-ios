import UIKit
import UIKit_iOS

final class PayShopAvailabilityContentView: UIView {
    var skeletonView: SkrullableView?
    private var isLoading: Bool = false

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
            stopLoadingIfNeeded()
            cashbackLabel.text = R.string.localizable.shopMerchantsCashbackFormat(
                cashback,
                preferredLanguages: locale?.rLanguages
            )
        case .loading:
            startLoadingIfNeeded()
        case .error:
            stopLoadingIfNeeded()
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

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
        }
    }
}

extension PayShopAvailabilityContentView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [cashbackLabel]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let skeletonSize = CGSize(width: spaceSize.width - 80, height: 18)
        let offset = CGPoint(
            x: spaceSize.width / 2 - skeletonSize.width / 2,
            y: logoView.frame.maxY + 8 + cashbackLabel.font.lineHeight / 2 - skeletonSize.height / 2
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: skeletonSize
            )
        ]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

typealias PayShopAvailabilityCell = CollectionViewContainerCell<PayShopAvailabilityContentView>
