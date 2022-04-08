import UIKit
import SoraUI
import SoraFoundation

struct StakingRewardSkeletonOptions: OptionSet {
    typealias RawValue = UInt8

    static let reward = StakingRewardSkeletonOptions(rawValue: 1 << 0)
    static let price = StakingRewardSkeletonOptions(rawValue: 1 << 1)

    let rawValue: UInt8

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

final class StakingRewardView: UIView {
    let backgroundView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12.0
        view.clipsToBounds = true
        view.image = R.image.imageStakingReward()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularSubheadline
        return label
    }()

    let rewardView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.textAlignment = .left
        view.valueTop.font = .boldTitle2
        view.valueBottom.textColor = R.color.colorTransparentText()
        view.valueBottom.textAlignment = .left
        view.valueBottom.font = .regularSubheadline
        view.spacing = 4.0
        return view
    }()

    private var skeletonView: SkrullableView?
    private var skeletonOptions: StakingRewardSkeletonOptions?

    private var viewModel: LocalizableResource<StakingRewardViewModel>?

    var locale = Locale.current {
        didSet {
            setupLocalization()
            applyViewModel()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 116.0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let options = skeletonOptions {
            setupSkeleton(for: options)
        }
    }

    func bind(viewModel: LocalizableResource<StakingRewardViewModel>) {
        self.viewModel = viewModel
        applyViewModel()
    }

    private func applyViewModel() {
        guard let viewModel = viewModel?.value(for: locale) else {
            rewardView.bind(topValue: "", bottomValue: nil)
            setupSkeleton(for: [.reward, .price])
            return
        }

        let title = viewModel.amount.value ?? ""
        let price: String? = viewModel.price?.value
        rewardView.bind(topValue: title, bottomValue: price)

        var newSkeletonOptions: StakingRewardSkeletonOptions = []

        if title.isEmpty {
            newSkeletonOptions.insert(.reward)
            newSkeletonOptions.insert(.price)
        }

        if let price = price, price.isEmpty {
            newSkeletonOptions.insert(.price)
        }

        setupSkeleton(for: newSkeletonOptions)
    }

    private func setupLocalization() {
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable.stakingRewardWidgetTitle(preferredLanguages: languages)
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(20.0)
        }

        addSubview(rewardView)
        rewardView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
        }
    }

    private func setupSkeleton(for options: StakingRewardSkeletonOptions) {
        skeletonOptions = nil

        guard !options.isEmpty else {
            skeletonView?.removeFromSuperview()
            skeletonView = nil
            return
        }

        skeletonOptions = options

        let spaceSize = frame.size

        guard spaceSize.width > 0.0, spaceSize.height > 0.0 else {
            return
        }

        let skeletons = createSkeletons(for: spaceSize, options: options)

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: skeletons
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
            insertSubview(view, aboveSubview: backgroundView)

            currentSkeletonView = view
            skeletonView = view

            view.startSkrulling()
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(
        for spaceSize: CGSize,
        options: StakingRewardSkeletonOptions
    ) -> [Skeletonable] {
        var skeletons: [Skeletonable] = []

        if options.contains(StakingRewardSkeletonOptions.reward) {
            let offset = CGPoint(x: 0.0, y: 12.0)
            skeletons.append(
                SingleSkeleton.createRow(
                    under: titleLabel,
                    containerView: backgroundView,
                    spaceSize: spaceSize,
                    offset: offset,
                    size: UIConstants.skeletonBigRowSize
                )
            )
        }

        if options.contains(StakingRewardSkeletonOptions.price) {
            let offset = CGPoint(x: 0.0, y: 41.0)
            skeletons.append(
                SingleSkeleton.createRow(
                    under: titleLabel,
                    containerView: backgroundView,
                    spaceSize: spaceSize,
                    offset: offset,
                    size: UIConstants.skeletonSmallRowSize
                )
            )
        }

        return skeletons
    }
}

extension StakingRewardView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonOptions = skeletonOptions else {
            return
        }

        setupSkeleton(for: skeletonOptions)
    }
}
