import UIKit
import SoraUI
import SoraFoundation

struct StakingRewardSkeletonOptions: OptionSet {
    typealias RawValue = UInt8

    static let reward = StakingStateSkeletonOptions(rawValue: 1 << 0)
    static let price = StakingStateSkeletonOptions(rawValue: 1 << 1)

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
        label.textColor = R.color.colorWhite48()
        label.font = .p1Paragraph
        return label
    }()

    let rewardView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.font = .title2
        view.valueBottom.textColor = R.color.colorTransparentText()
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

    func bind(viewModel: LocalizableResource<StakingRewardViewModel>) {
        self.viewModel = viewModel
        applyViewModel()
    }

    private func applyViewModel() {
        guard let viewModel = viewModel?.value(for: locale) else {
            return
        }

        rewardView.bind(topValue: viewModel.amount.value ?? "", bottomValue: viewModel.price?.value)
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
            make.top.equalTo(titleLabel.snp.bottom).offset(2.0)
        }
    }

    private func setupSkeleton(for options: StakingRewardSkeletonOptions) {
        skeletonOptions = nil

        guard !options.isEmpty else {
            skeletonView?.removeFromSuperview()
            skeletonView = nil
            return
        }

        let spaceSize = backgroundView.frame.size

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
        return []
    }
}
