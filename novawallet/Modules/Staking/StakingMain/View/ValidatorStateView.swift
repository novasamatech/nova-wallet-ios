import Foundation
import SoraFoundation

class ValidatorStateView: StakingStateView, LocalizableViewProtocol {
    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<ValidationViewModel>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
    }

    func bind(viewModel: LocalizableResource<ValidationViewModel>) {
        localizableViewModel = viewModel

        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingValidatorSummaryTitle(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

        stakeAmountView.bind(topValue: viewModel.totalStakedAmount, bottomValue: viewModel.totalStakedPrice)

        if case .undefined = viewModel.status {
            toggleStatus(false)
        } else {
            toggleStatus(true)
        }

        var skeletonOptions: StakingStateSkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        switch viewModel.status {
        case .undefined:
            skeletonOptions.insert(.status)
        case let .active(era):
            presentActiveStatus(for: era)
        case let .inactive(era):
            presentInactiveStatus(for: era)
        }

        if !skeletonOptions.isEmpty, viewModel.hasPrice {
            skeletonOptions.insert(.price)
        }

        setupSkeleton(options: skeletonOptions)
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusView.isHidden = !shouldShow
    }

    private func presentActiveStatus(for _: UInt32) {
        statusView.glowingView.outerFillColor = R.color.colorGreen24()!
        statusView.glowingView.innerFillColor = R.color.colorGreen()!
        statusView.detailsLabel.textColor = R.color.colorGreen()!

        statusView.detailsLabel.text = R.string.localizable.stakingNominatorStatusActive(
            preferredLanguages: locale.rLanguages
        ).uppercased()
    }

    private func presentInactiveStatus(for _: UInt32) {
        statusView.glowingView.outerFillColor = R.color.colorWhite16()!
        statusView.glowingView.innerFillColor = R.color.colorWhite48()!
        statusView.detailsLabel.textColor = R.color.colorWhite80()!

        statusView.detailsLabel.text = R.string.localizable.stakingNominatorStatusInactive(
            preferredLanguages: locale.rLanguages
        ).uppercased()
    }
}
