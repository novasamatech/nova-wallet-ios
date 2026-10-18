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

    let rootBarView = SubtensorStakeToRootBarView()

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
        }

        addSubview(rootBarView)
        rootBarView.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Constants.barBottomInset)
            make.height.equalTo(SubtensorStakeToRootBarView.preferredHeight)
        }

        addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(controlsView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(rootBarView.snp.top)
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
    }
}

final class SubtensorSubnetPicksHeaderView: UITableViewHeaderFooterView {
    static let preferredHeight: CGFloat = 36

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldCaps1Secondary)
    }

    let captionLabel: UILabel = .create { view in
        view.apply(style: .caption1Secondary)
        view.textAlignment = .right
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, caption: String) {
        titleLabel.text = title
        captionLabel.text = caption
    }

    private func setupLayout() {
        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorSecondaryScreenBackground()

        [titleLabel, captionLabel].forEach(contentView.addSubview)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        captionLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }
    }
}
