import UIKit
import SoraUI
import SoraFoundation

protocol NetworkInfoViewDelegate: AnyObject {
    func animateAlongsideWithInfo(view: NetworkInfoView)
    func didChangeExpansion(isExpanded: Bool, view: NetworkInfoView)
}

final class NetworkInfoView: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 48.0
        static let rowHeight: CGFloat = 48.0
        static let contentMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        static let stackViewBottomInset: CGFloat = 4.0
    }

    let backgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        return view
    }()

    let networkInfoContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }()

    let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let titleControl: ActionTitleControl = {
        let control = ActionTitleControl()
        control.imageView.image = R.image.iconArrowUp()?.tinted(with: R.color.colorWhite48()!)
        control.identityIconAngle = CGFloat.pi
        control.activationIconAngle = 0.0
        control.titleLabel.textColor = R.color.colorWhite()
        control.titleLabel.font = .regularSubheadline
        control.layoutType = .flexible
        control.contentInsets = Constants.contentMargins
        control.horizontalSpacing = 0.0
        control.iconDisplacement = 0.0
        control.imageView.isUserInteractionEnabled = false
        control.activate(animated: false)
        return control
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 0.0
        stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    let totalStakedView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applySingleValueBlurStyle()
        return view
    }()

    let minimumStakedView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applySingleValueBlurStyle()
        return view
    }()

    let activeNominatorsView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applySingleValueBlurStyle()
        return view
    }()

    let stakingPeriodView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applySingleValueBlurStyle()
        return view
    }()

    let unstakingPeriodView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applySingleValueBlurStyle()
        view.borderView.borderType = .none
        return view
    }()

    weak var delegate: NetworkInfoViewDelegate?

    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    var expanded: Bool { titleControl.isActivated }

    private var skeletonView: SkrullableView?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<NetworkStakingInfoViewModel>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupHandlers()
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

    func setExpanded(_ value: Bool, animated: Bool) {
        guard value != expanded else {
            return
        }

        if value {
            titleControl.activate(animated: animated)
        } else {
            titleControl.deactivate(animated: animated)
        }

        applyExpansion(animated: animated)
    }

    func bind(viewModel: LocalizableResource<NetworkStakingInfoViewModel>?) {
        localizableViewModel = viewModel

        if viewModel != nil {
            stopLoadingIfNeeded()

            applyViewModel()
        } else {
            startLoading()
        }
    }

    private func setupHandlers() {
        titleControl.addTarget(self, action: #selector(actionToggleExpansion), for: .valueChanged)
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleControl)
        titleControl.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.headerHeight)
        }

        addSubview(networkInfoContainer)
        networkInfoContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleControl.snp.bottom)
        }

        networkInfoContainer.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(Constants.stackViewBottomInset)
        }

        let views = [
            totalStakedView,
            minimumStakedView,
            activeNominatorsView,
            stakingPeriodView,
            unstakingPeriodView
        ]

        views.forEach { view in
            stackView.addArrangedSubview(view)

            view.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }
        }
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        let localizedViewModel = viewModel.value(for: locale)

        totalStakedView.valueTop.text = localizedViewModel.totalStake?.amount

        if let price = localizedViewModel.totalStake?.price, !price.isEmpty {
            totalStakedView.valueBottom.text = price
        } else {
            totalStakedView.resetToSingleValue()
        }

        minimumStakedView.valueTop.text = localizedViewModel.minimalStake?.amount

        if let price = localizedViewModel.minimalStake?.price, !price.isEmpty {
            minimumStakedView.valueBottom.text = price
        } else {
            minimumStakedView.resetToSingleValue()
        }

        activeNominatorsView.valueTop.text = localizedViewModel.activeNominators
        stakingPeriodView.valueTop.text = localizedViewModel.stakingPeriod
        unstakingPeriodView.valueTop.text = localizedViewModel.lockUpPeriod
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        titleControl.titleLabel.text = R.string.localizable.stakingNetworkInfoTitle(
            preferredLanguages: languages
        )

        titleControl.invalidateLayout()

        totalStakedView.titleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages)
        minimumStakedView.titleLabel.text = R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages)
        activeNominatorsView.titleLabel.text = R.string.localizable
            .stakingMainActiveNominatorsTitle(preferredLanguages: languages)
        stakingPeriodView.titleLabel.text = R.string.localizable.stakingNetworkInfoStakingPeriodTitle(
            preferredLanguages: languages
        )
        unstakingPeriodView.titleLabel.text = R.string.localizable
            .stakingMainLockupPeriodTitle_v190(preferredLanguages: languages)

        setNeedsLayout()
    }

    private func applyExpansion(animated: Bool) {
        if animated {
            expansionAnimator.animate(block: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.applyExpansionState()

                let animation = CABasicAnimation()
                animation.toValue = strongSelf.backgroundView.blurMaskView?.shapePath
                strongSelf.backgroundView.blurMaskView?.layer
                    .add(animation, forKey: #keyPath(CAShapeLayer.path))

                strongSelf.delegate?.animateAlongsideWithInfo(view: strongSelf)
            }, completionBlock: nil)
        } else {
            applyExpansionState()
            setNeedsLayout()
        }
    }

    private func applyExpansionState() {
        if expanded {
            contentView.snp.updateConstraints { make in
                make.top.equalToSuperview()
            }

            networkInfoContainer.alpha = 1.0
            delegate?.didChangeExpansion(isExpanded: true, view: self)
        } else {
            contentView.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(
                    -5 * Constants.rowHeight - Constants.stackViewBottomInset
                )
            }

            networkInfoContainer.alpha = 0.0
            delegate?.didChangeExpansion(isExpanded: false, view: self)
        }
    }

    func startLoading() {
        guard skeletonView == nil else {
            return
        }

        totalStakedView.valueTop.alpha = 0.0
        totalStakedView.valueBottom.alpha = 0.0
        minimumStakedView.valueTop.alpha = 0.0
        minimumStakedView.valueBottom.alpha = 0.0
        activeNominatorsView.valueTop.alpha = 0.0
        stakingPeriodView.valueTop.alpha = 0.0
        unstakingPeriodView.valueTop.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        totalStakedView.valueTop.alpha = 1.0
        totalStakedView.valueBottom.alpha = 1.0
        minimumStakedView.valueTop.alpha = 1.0
        minimumStakedView.valueBottom.alpha = 1.0
        activeNominatorsView.valueTop.alpha = 1.0
        stakingPeriodView.valueTop.alpha = 1.0
        unstakingPeriodView.valueTop.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = CGSize(
            width: frame.width,
            height: 5 * Constants.rowHeight + Constants.stackViewBottomInset
        )

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
            contentView.insertSubview(view, at: 0)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)

        let horizontalInsetWidth = Constants.contentMargins.left + Constants.contentMargins.right

        let doubleValueBigOffset = CGPoint(
            x: networkInfoContainer.frame.width - horizontalInsetWidth - bigRowSize.width,
            y: Constants.rowHeight / 2.0 - bigRowSize.height - 3.0
        )

        let doubleValueSmallOffset = CGPoint(
            x: networkInfoContainer.frame.width - horizontalInsetWidth - smallRowSize.width,
            y: Constants.rowHeight / 2.0 + 3.0
        )

        let singleValueOffset = CGPoint(
            x: networkInfoContainer.frame.width - horizontalInsetWidth - bigRowSize.width,
            y: Constants.rowHeight / 2.0 - bigRowSize.height / 2.0
        )

        return [
            SingleSkeleton.createRow(
                on: totalStakedView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: doubleValueBigOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                on: totalStakedView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: doubleValueSmallOffset,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                on: minimumStakedView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: doubleValueBigOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                on: minimumStakedView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: doubleValueSmallOffset,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                on: activeNominatorsView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: singleValueOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                on: stakingPeriodView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: singleValueOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                on: unstakingPeriodView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: singleValueOffset,
                size: bigRowSize
            )
        ]
    }

    // MARK: Action

    @objc func actionToggleExpansion() {
        applyExpansion(animated: true)
    }
}

extension NetworkInfoView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard skeletonView != nil else {
            return
        }

        setupSkeleton()
    }
}
