import UIKit
import UIKit_iOS
import Foundation_iOS

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

    let backgroundView: BlockBackgroundView = {
        let view = BlockBackgroundView()
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
        control.imageView.image = R.image.iconArrowUp()?.tinted(with: R.color.colorIconSecondary()!)
        control.identityIconAngle = CGFloat.pi
        control.activationIconAngle = 0.0
        control.titleLabel.apply(style: .regularSubhedlineSecondary)
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

    var skeletonView: SkrullableView?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    var statics: StakingMainStaticViewModelProtocol? {
        didSet {
            applyLocalization()
        }
    }

    private var viewModel: NetworkStakingInfoViewModel?

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

        if viewModel?.hasLoadingData == true {
            updateLoadingState()
            skeletonView?.restartSkrulling()
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

    func bind(viewModel: NetworkStakingInfoViewModel) {
        stopLoadingIfNeeded()

        self.viewModel = viewModel

        applyViewModel()

        if viewModel.hasLoadingData {
            startLoadingIfNeeded()
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

    private func applyCell(viewModel: LoadableViewModelState<(String?, String?)>?, to cell: TitleMultiValueView) {
        if let loadableViewModel = viewModel {
            cell.isHidden = false

            let title = loadableViewModel.value?.0
            let optSubtitle = loadableViewModel.value?.1

            cell.valueTop.text = title

            if let subtitle = optSubtitle, !subtitle.isEmpty {
                cell.valueBottom.text = subtitle
            } else {
                cell.resetToSingleValue()
            }
        } else {
            cell.isHidden = true
        }
    }

    private func applyViewModel() {
        guard let viewModel = viewModel else {
            return
        }

        applyCell(viewModel: viewModel.totalStake?.map(with: { ($0.amount, $0.price) }), to: totalStakedView)
        applyCell(viewModel: viewModel.minimalStake?.map(with: { ($0.amount, $0.price) }), to: minimumStakedView)
        applyCell(viewModel: viewModel.activeNominators?.map(with: { ($0, nil) }), to: activeNominatorsView)
        applyCell(viewModel: viewModel.stakingPeriod?.map(with: { ($0, nil) }), to: stakingPeriodView)
        applyCell(viewModel: viewModel.lockUpPeriod?.map(with: { ($0, nil) }), to: unstakingPeriodView)
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        totalStakedView.titleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages)
        minimumStakedView.titleLabel.text = R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages)

        if let statics = statics {
            activeNominatorsView.titleLabel.text = statics.networkInfoActiveNominators(for: locale)

            titleControl.titleLabel.text = statics.networkInfoTitle(for: locale)
        } else {
            activeNominatorsView.titleLabel.text = R.string.localizable
                .stakingMainActiveNominatorsTitle(preferredLanguages: languages)

            titleControl.titleLabel.text = R.string(preferredLanguages: languages
            ).localizable.stakingNetworkInfoTitle()
        }

        titleControl.invalidateLayout()

        stakingPeriodView.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.stakingNetworkInfoStakingPeriodTitle()
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
                animation.toValue = strongSelf.backgroundView.contentView?.shapePath
                strongSelf.backgroundView.contentView?.layer
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

    // MARK: Action

    @objc func actionToggleExpansion() {
        applyExpansion(animated: true)
    }
}

extension NetworkInfoView: SkeletonableView {
    var skeletonSuperview: UIView {
        contentView
    }

    var hidingViews: [UIView] {
        guard let viewModel = viewModel, viewModel.hasLoadingData else {
            return []
        }

        var views: [UIView] = []

        if viewModel.totalStake?.isLoading == true {
            views.append(totalStakedView.valueTop)
            views.append(totalStakedView.valueBottom)
        }

        if viewModel.minimalStake?.isLoading == true {
            views.append(minimumStakedView.valueTop)
            views.append(minimumStakedView.valueBottom)
        }

        if viewModel.activeNominators?.isLoading == true {
            views.append(activeNominatorsView.valueTop)
            views.append(activeNominatorsView.valueBottom)
        }

        if viewModel.stakingPeriod?.isLoading == true {
            views.append(stakingPeriodView.valueTop)
            views.append(stakingPeriodView.valueBottom)
        }

        if viewModel.lockUpPeriod?.isLoading == true {
            views.append(unstakingPeriodView.valueTop)
            views.append(unstakingPeriodView.valueBottom)
        }

        return views
    }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
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

        var skeletons: [Skeletonable] = []

        if viewModel?.totalStake?.isLoading == true {
            skeletons.append(contentsOf: [
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
                )
            ])
        }

        if viewModel?.minimalStake?.isLoading == true {
            skeletons.append(contentsOf: [
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
                )
            ])
        }

        if viewModel?.activeNominators?.isLoading == true {
            skeletons.append(
                SingleSkeleton.createRow(
                    on: activeNominatorsView,
                    containerView: contentView,
                    spaceSize: spaceSize,
                    offset: singleValueOffset,
                    size: bigRowSize
                )
            )
        }

        if viewModel?.stakingPeriod?.isLoading == true {
            skeletons.append(
                SingleSkeleton.createRow(
                    on: stakingPeriodView,
                    containerView: contentView,
                    spaceSize: spaceSize,
                    offset: singleValueOffset,
                    size: bigRowSize
                )
            )
        }

        if viewModel?.lockUpPeriod?.isLoading == true {
            skeletons.append(
                SingleSkeleton.createRow(
                    on: unstakingPeriodView,
                    containerView: contentView,
                    spaceSize: spaceSize,
                    offset: singleValueOffset,
                    size: bigRowSize
                )
            )
        }

        return skeletons
    }
}

extension NetworkInfoView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.restartSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard skeletonView != nil else {
            return
        }

        updateLoadingState()
        skeletonView?.restartSkrulling()
    }
}
