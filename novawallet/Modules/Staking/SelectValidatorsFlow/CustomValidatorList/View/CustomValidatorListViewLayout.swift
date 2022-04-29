import SoraUI

final class CustomValidatorListViewLayout: UIView {
    private enum Constants {
        static let auxButtonHeight: CGFloat = 24.0
        static let auxButtonContainerHeight: CGFloat = 56.0
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        return stackView
    }()

    private let stackContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()
        return view
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 100.0, right: 0.0)
        return tableView
    }()

    let fillRestButton: RoundedButton = {
        let button = createRoundedButton()
        button.roundedBackgroundView?.fillColor = R.color.colorAccent()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorAccent()!
        return button
    }()

    let clearButton: RoundedButton = {
        let button = createRoundedButton()
        button.roundedBackgroundView?.fillColor = R.color.colorDarkInactive()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorDarkInactive()!
        return button
    }()

    let deselectButton: RoundedButton = {
        let button = createRoundedButton()
        button.roundedBackgroundView?.fillColor = R.color.colorDarkInactive()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorDarkInactive()!
        return button
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.contentOpacityWhenDisabled = 1.0
        return button
    }()

    private static func createRoundedButton() -> RoundedButton {
        let button = RoundedButton()
        button.applyEnabledStyle()
        button.roundedBackgroundView?.cornerRadius = 10.0
        button.contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        button.imageWithTitleView?.titleColor = R.color.colorWhite()!
        return button
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        stackView.addArrangedSubview(fillRestButton)
        stackView.addArrangedSubview(clearButton)
        stackView.addArrangedSubview(deselectButton)

        stackContainerView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.bottom.equalToSuperview().inset(12.0)
            make.leading.equalTo(stackContainerView.snp.leading).inset(UIConstants.horizontalInset)
            make.trailing.equalTo(stackContainerView.snp.trailing).inset(UIConstants.horizontalInset)
        }

        scrollView.addSubview(stackContainerView)
        stackContainerView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.auxButtonContainerHeight)
        }

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.trailing.leading.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(Constants.auxButtonContainerHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
