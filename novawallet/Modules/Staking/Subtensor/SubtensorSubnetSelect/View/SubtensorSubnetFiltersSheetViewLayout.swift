import UIKit
import UIKit_iOS

final class SubtensorSubnetFiltersSheetViewLayout: UIView {
    static let contentHeight: CGFloat = Constants.titleTopInset + Constants.titleHeight + Constants.filtersTopSpacing +
        Constants.rowHeight + Constants.actionTopSpacing + UIConstants.actionHeight + Constants.bottomInset

    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
    }

    let filtersView = StackTableView()

    let thinPoolsCell = SubtensorSubnetFiltersSheetViewLayout.createFilterCell()

    let aboveAverageCell = SubtensorSubnetFiltersSheetViewLayout.createFilterCell()

    let unavailableLabel: UILabel = .create { view in
        view.apply(style: .caption1Negative)
    }

    let actionButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.color = R.color.colorIconSecondary()
        view.hidesWhenStopped = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorSubnetFiltersViewModel) {
        titleLabel.text = viewModel.title

        thinPoolsCell.titleLabel.text = viewModel.thinPoolsTitle
        thinPoolsCell.subtitleLabel.text = viewModel.thinPoolsDetails
        thinPoolsCell.switchControl.setOn(viewModel.filters.hideThinPools, animated: true)

        aboveAverageCell.titleLabel.text = viewModel.aboveAverageTitle
        aboveAverageCell.subtitleLabel.text = viewModel.aboveAverageDetails
        aboveAverageCell.switchControl.setOn(viewModel.filters.onlyAboveThirtyDayAverage, animated: true)

        unavailableLabel.text = viewModel.unavailableText
        unavailableLabel.isHidden = viewModel.unavailableText == nil

        actionButton.imageWithTitleView?.title = viewModel.actionTitle
        actionButton.isEnabled = !viewModel.isLoading

        if viewModel.isLoading {
            actionButton.applyDisabledStyle()
            activityIndicator.startAnimating()
        } else {
            actionButton.applyEnabledStyle()
            activityIndicator.stopAnimating()
        }

        actionButton.invalidateLayout()
    }
}

private extension SubtensorSubnetFiltersSheetViewLayout {
    static func createFilterCell() -> StackSwitchCell {
        let cell = StackSwitchCell()
        cell.titleLabel.apply(style: .regularBodyPrimary)
        cell.titleLabel.adjustsFontSizeToFitWidth = true
        cell.titleLabel.minimumScaleFactor = Constants.titleMinimumScale
        return cell
    }

    func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(Constants.titleHeight)
        }

        addSubview(filtersView)
        filtersView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.filtersTopSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        filtersView.addArrangedSubview(thinPoolsCell)
        filtersView.setCustomHeight(Constants.rowHeight, at: 0)

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.top.equalTo(filtersView.snp.bottom).offset(Constants.actionTopSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(unavailableLabel)
        unavailableLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(filtersView.snp.bottom).offset(Constants.actionTopSpacing / 2)
        }

        actionButton.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }
    }

    enum Constants {
        static let titleTopInset: CGFloat = 8
        static let titleHeight: CGFloat = 28
        static let filtersTopSpacing: CGFloat = 10
        static let rowHeight: CGFloat = 54
        static let actionTopSpacing: CGFloat = 28
        static let bottomInset: CGFloat = 16
        static let titleMinimumScale: CGFloat = 0.8
    }
}
