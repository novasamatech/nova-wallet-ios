import UIKit
import SoraUI

final class AssetListTotalBalanceCell: UICollectionViewCell {
    private enum Constants {
        static let bottomInset: CGFloat = 20.0
    }

    let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        return view
    }()

    let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .detailsIcon

        view.detailsLabel.numberOfLines = 1
        view.detailsLabel.textColor = R.color.colorTransparentText()
        view.detailsLabel.font = .regularSubheadline

        view.imageView.image = R.image.iconInfoFilled()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite48()!)
        view.iconWidth = 16.0
        view.spacing = 4.0

        return view
    }()

    let amountLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.color.colorWhite()
        view.font = .boldLargeTitle
        view.textAlignment = .center
        return view
    }()

    let locksView: BorderedIconLabelView = .create {
        let color = R.color.colorWhite64()!
        $0.iconDetailsView.imageView.image = R.image.iconBrowserSecurity()?.withTintColor(color)
        $0.iconDetailsView.detailsLabel.font = .regularFootnote
        $0.iconDetailsView.detailsLabel.textColor = color
        $0.iconDetailsView.spacing = 4.0
        $0.contentInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        $0.isHidden = true
    }

    private var skeletonView: SkrullableView?

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if skeletonView != nil {
            setupSkeleton()
        }
    }

    func bind(viewModel: AssetListHeaderViewModel) {
        switch viewModel.amount {
        case let .loaded(value), let .cached(value):
            amountLabel.text = value
            locksView.iconDetailsView.detailsLabel.text = viewModel.locksAmount
            locksView.isHidden = viewModel.locksAmount == nil
            stopLoadingIfNeeded()
        case .loading:
            amountLabel.text = ""
            locksView.isHidden = true
            startLoadingIfNeeded()
        }
    }

    private func setupLocalization() {
        titleView.detailsLabel.text = R.string.localizable.walletTotalBalance(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        contentView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backgroundBlurView.snp.top).offset(20.0)
        }

        let amountView = UIStackView(arrangedSubviews: [
            amountLabel,
            locksView
        ])
        amountView.spacing = 8.0
        amountView.axis = .vertical
        amountView.alignment = .center

        contentView.addSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(titleView.snp.bottom).offset(3)
            make.leading.equalTo(backgroundBlurView).offset(8.0)
            make.trailing.equalTo(backgroundBlurView).offset(-8.0)
            make.bottom.equalToSuperview().inset(Constants.bottomInset)
        }
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        amountLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        amountLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = contentView.frame.size

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            contentView.insertSubview(view, aboveSubview: backgroundBlurView)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 96.0, height: 16.0)

        let offsetY = spaceSize.height - Constants.bottomInset - amountLabel.font.lineHeight / 2.0 -
            bigRowSize.height / 2.0

        let offset = CGPoint(
            x: spaceSize.width / 2.0 - bigRowSize.width / 2.0,
            y: offsetY
        )

        return [
            SingleSkeleton.createRow(
                on: contentView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: offset,
                size: bigRowSize
            )
        ]
    }
}
