import UIKit
import SoraUI
import SoraFoundation

protocol NetworkInfoViewDelegate: AnyObject {
    func animateAlongsideWithInfo(view: NetworkInfoView)
    func didChangeExpansion(isExpanded: Bool, view: NetworkInfoView)
}

final class NetworkInfoView: UIView {
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

    let titleControl: ActionTitleControl = {
        let control = ActionTitleControl()
        control.imageView.image = R.image.iconArrowUp()
        control.imageView.tintColor = R.color.colorWhite()
        control.identityIconAngle = 180
        control.titleLabel.textColor = R.color.colorWhite()
        control.titleLabel.font = .p1Paragraph
        control.layoutType = .flexible
        control.contentInsets = UIEdgeInsets(top: 4.0, left: 16.0, bottom: 4.0, right: 16.0)
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
        view.applyBlurStyle()
        return view
    }()

    let minimumStakedView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applyBlurStyle()
        return view
    }()

    let activeNominatorsView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applyBlurStyle()
        return view
    }()

    let stakingPeriodView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applyBlurStyle()
        return view
    }()

    let unstakingPeriodView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.applyBlurStyle()
        return view
    }()

    private var contentTop: NSLayoutConstraint?
    private var contentHeight: NSLayoutConstraint?

    weak var delegate: NetworkInfoViewDelegate?

    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    var expanded: Bool { titleControl.isActivated }

    private var skeletonView: SkrullableView?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyTitle()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?
    private var chainName: String?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    func bind(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
        localizableViewModel = viewModel

        if viewModel != nil {
            stopLoadingIfNeeded()

            applyViewModel()
        } else {
            startLoading()
        }
    }

    func bind(chainName: String) {
        self.chainName = chainName

        applyTitle()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleControl)
        titleControl.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(48.0)
        }

        addSubview(networkInfoContainer)
        networkInfoContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleControl.snp.bottom)
        }

        networkInfoContainer.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
                make.height.equalTo(48.0)
            }
        }
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        let localizedViewModel = viewModel.value(for: locale)

        totalStakedView.valueTop.text = localizedViewModel.totalStake?.amount
        totalStakedView.valueBottom.text = localizedViewModel.totalStake?.price
        minimumStakedView.valueTop.text = localizedViewModel.minimalStake?.amount
        minimumStakedView.valueBottom.text = localizedViewModel.minimalStake?.price
        activeNominatorsView.valueTop.text = localizedViewModel.activeNominators
        unstakingPeriodView.valueTop.text = localizedViewModel.lockUpPeriod
    }

    private func applyTitle() {
        guard let chainName = chainName else {
            return
        }

        titleControl.titleLabel.text = R.string.localizable
            .stakingMainNetworkTitle(chainName, preferredLanguages: locale.rLanguages)
        titleControl.invalidateLayout()
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        totalStakedView.titleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages)
        minimumStakedView.titleLabel.text = R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages)
        activeNominatorsView.titleLabel.text = R.string.localizable
            .stakingMainActiveNominatorsTitle(preferredLanguages: languages)
        stakingPeriodView.titleLabel.text = "Staking period"
        stakingPeriodView.valueTop.text = "Unlimited"
        unstakingPeriodView.titleLabel.text = R.string.localizable
            .stakingMainLockupPeriodTitle_v190(preferredLanguages: languages)
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
            stackView.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(-5 * 48 - 8)
            }

            networkInfoContainer.alpha = 1.0
            delegate?.didChangeExpansion(isExpanded: true, view: self)
        } else {
            stackView.snp.updateConstraints { make in
                make.top.equalToSuperview()
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
        unstakingPeriodView.valueTop.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = networkInfoContainer.frame.size

        let skeletonView = Skrull(
            size: networkInfoContainer.frame.size,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        networkInfoContainer.insertSubview(skeletonView, at: 0)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)
        let bigOffset = CGPoint(
            x: networkInfoContainer.frame.width - 32.0 - bigRowSize.width,
            y: 7.0
        )
        let smallOffset = CGPoint(
            x: networkInfoContainer.frame.width - 32.0 - smallRowSize.width,
            y: bigOffset.y + bigRowSize.height + 2.0
        )

        return [
            SingleSkeleton.createRow(
                under: titleControl,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: bigOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                under: titleControl,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: smallOffset,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                under: totalStakedView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: bigOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                under: totalStakedView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: smallOffset,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                under: minimumStakedView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: bigOffset,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                under: stakingPeriodView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: bigOffset,
                size: bigRowSize
            ),
        ]
    }

    // MARK: Action

    @IBAction func actionToggleExpansion() {
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
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != networkInfoContainer.frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }
}
