import UIKit
import UIKit_iOS

final class SubtensorSubnetSelectViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchTextField: UITextField {
        searchView.searchBar.textField
    }

    let sortView: BorderedActionControlView = .create { view in
        view.contentInsets = Constants.sortInsets
    }

    let filterButton: UIButton = .create { view in
        view.setImage(R.image.iconFilter(), for: .normal)
    }

    let captionLabel: UILabel = .create { view in
        view.apply(style: .caption1Secondary)
        view.textAlignment = .right
    }

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.rowHeight = SubtensorSubnetCell.preferredHeight
        view.sectionHeaderTopPadding = 0
        view.keyboardDismissMode = .onDrag
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Constants.barTopSpacing, right: 0)
    }

    let emptyStateView: EmptyStateView = .create { view in
        view.image = R.image.iconEmptySearch()
        view.titleColor = R.color.colorTextSecondary()!
        view.titleFont = .regularFootnote
        view.isHidden = true
    }

    let errorView: InlineAlertView = .create { view in
        view.apply(style: .warning)
        view.isHidden = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(controls viewModel: SubtensorSubnetListViewModel) {
        sortView.bind(title: viewModel.chipTitle)
        sortView.control.isEnabled = viewModel.areControlsEnabled
        sortView.alpha = viewModel.areControlsEnabled ? 1 : Constants.inactiveAlpha

        filterButton.setImage(
            viewModel.isFilterActive ? R.image.iconFilterActive() : R.image.iconFilter(),
            for: .normal
        )

        filterButton.isEnabled = viewModel.areControlsEnabled
        filterButton.alpha = viewModel.areControlsEnabled ? 1 : Constants.inactiveAlpha

        captionLabel.text = viewModel.caption
        captionLabel.isHidden = viewModel.caption == nil
    }

    func bind(emptyText: String?) {
        emptyStateView.title = emptyText
        emptyStateView.isHidden = emptyText == nil
    }

    func bind(failure: SubtensorSubnetListViewModel.Failure?) {
        guard let failure else {
            errorView.isHidden = true
            return
        }

        let text = NSMutableAttributedString(
            string: failure.title,
            attributes: [.font: UIFont.semiBoldCaption1, .foregroundColor: R.color.colorTextPrimary()!]
        )

        text.append(NSAttributedString(string: "\n"))

        text.append(NSAttributedString(
            string: failure.details,
            attributes: [.font: UIFont.caption1, .foregroundColor: R.color.colorTextSecondary()!]
        ))

        errorView.contentView.detailsLabel.attributedText = text
        errorView.setLink(title: failure.retryTitle)
        errorView.isHidden = false
    }
}

private extension SubtensorSubnetSelectViewLayout {
    func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.searchBarHeight)
        }

        let controlsView = UIView()

        addSubview(controlsView)
        controlsView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(Constants.controlsTopSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(Constants.filterSize)
        }

        [sortView, filterButton, captionLabel].forEach(controlsView.addSubview)

        sortView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        filterButton.snp.makeConstraints { make in
            make.leading.equalTo(sortView.snp.trailing).offset(Constants.filterSpacing)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.filterSize)
        }

        captionLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(filterButton.snp.trailing).offset(Constants.captionSpacing)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(controlsView.snp.bottom).offset(Constants.listTopSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.top).offset(SubtensorSubnetCell.preferredHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(tableView.snp.bottom)
        }

        addSubview(errorView)
        errorView.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.top).offset(SubtensorSubnetCell.preferredHeight + Constants.errorTopSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        captionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    enum Constants {
        static let searchBarHeight: CGFloat = 52
        static let controlsTopSpacing: CGFloat = 8
        static let sortInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 4)
        static let filterSize: CGFloat = 28
        static let filterSpacing: CGFloat = 7
        static let captionSpacing: CGFloat = 8
        static let listTopSpacing: CGFloat = 8
        static let barBottomInset: CGFloat = 8
        static let barTopSpacing: CGFloat = 8
        static let inactiveAlpha: CGFloat = 0.5
        static let errorTopSpacing: CGFloat = 16
    }
}
