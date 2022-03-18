import UIKit

final class SignerConnectViewLayout: UIView {
    let contentView = ScrollableContainerView()

    let appView: IconDetailsView = {
        let view = IconDetailsView()
        view.stackView.axis = .vertical
        view.stackView.spacing = 16.0
        return view
    }()

    let tableView = StackTableView()

    let accountView = StackTableCell()

    let statusView = StackTableCell()

    let connectionInfoView = StackTableCell()

    var locale = Locale.current {
        didSet {
            applyLocale()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocale()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocale() {
        statusView.titleLabel.text = R.string.localizable.commonStatus(
            preferredLanguages: locale.rLanguages
        )

        connectionInfoView.titleLabel.text = R.string.localizable
            .signerConnectConnectedTo(preferredLanguages: locale.rLanguages)
        accountView.titleLabel.text = R.string.localizable.accountInfoTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(appView)
        appView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: appView)

        contentView.stackView.addArrangedSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        tableView.addArrangedSubview(accountView)
        tableView.addArrangedSubview(statusView)
        tableView.addArrangedSubview(connectionInfoView)
    }
}
