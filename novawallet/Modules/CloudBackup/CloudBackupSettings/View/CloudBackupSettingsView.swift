import Foundation
import SoraUI

protocol CloudBackupSettingsViewDelegate: AnyObject {
    func didSelectSyncAction()
    func didSelectIssueAction()
}

final class CloudBackupSettingsView: UIView {
    let tableView = StackTableView()

    let syncCell = CloudBackupActionCell()

    let issueCell: StackTableCell?

    weak var delegate: CloudBackupSettingsViewDelegate?

    convenience init() {
        self.init(frame: .zero)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    private func setupHandlers() {
        syncCell.addTarget(
            self,
            action: #selector(actionSync),
            for: .touchUpInside
        )
    }

    private func setupIssueCellIfNeeded() -> StackActionCell {
        if let issueCell {
            return issueCell
        }

        let issueCell = StackTableCell()
        issueCell.titleLabel.apply(style: .semiboldFootnoteAccentText)

        issueCell.addTarget(
            self,
            action: #selector(actionIssue),
            for: .touchUpInside
        )

        self.issueCell = issueCell

        tableView.addArrangedSubview(issueCell)

        return issueCell
    }

    func bind(viewModel: CloudBackupSettingsViewModel) {
        syncCell.bind(
            status: viewModel.status,
            title: viewModel.title,
            lastSynced: viewModel.lastSynced
        )

        if let issue = viewModel.issue {
            let issueCell = setupIssueCellIfNeeded()
            issueCell.titleLabel.text = issue
        } else if let actionCell {
            actionCell.removeFromSuperview()
            actionCell = nil
        }

        switch viewModel.status {
        case .synced, .disabled:
            syncCell.isUserInteractionEnabled = false
        case .unsynced, .synced:
            syncCell.isUserInteractionEnabled = true
        }
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.addArrangedSubview(syncCell)
    }

    @objc func actionSync() {
        delegate?.didSelectSyncAction()
    }

    @objc func actionIssue() {
        delegate?.didSelectIssueAction()
    }
}

final class CloudBackupActionCell: RowView<
    GenericTitleValueView<GenericPairValueView<CloudBackupActionStateView, MultiValueView>, UIImageView>
> {
    var statusView: CloudBackupActionStateView {
        rowContentView.titleView.fView
    }

    var labelsView: MultiValueView {
        rowContentView.titleView.sView
    }

    var titleLabel: UILabel {
        rowContentView.titleView.sView.valueTop
    }

    var subtitleLabel: UILabel {
        rowContentView.titleView.sView.valueBottom
    }

    var iconView: UIImageView {
        rowContentView.valueView
    }

    func bind(status: CloudBackupSettingsViewModel.Status, title: String, lastSynced: String?) {
        statusView.bind(status: status)

        labelsView.bind(topValue: title, bottomValue: lastSynced)

        switch status {
        case .disabled, .syncing:
            iconView.image = nil
        case .unsynced, .synced:
            iconView.image = R.image.iconMore()
        }
    }

    private func setupStyle() {
        rowContentView.titleView.spacing = 12
        labelsView.spacing = 2

        titleLabel.apply(style: .semiboldBodyPrimary)
        subtitleLabel.apply(style: .caption1Primary)
    }
}

final class CloudBackupActionStateView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.cornerRadius = 20
    }

    let iconView = UIImageView()

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.color = R.color.colorIndicatorShimmering()!
        view.hidesWhenStopped = true
    }

    override var intrinsicContentSize: CGSize {
        let cornerRadius = backgroundView.cornerRadius

        return CGSize(width: 2 * cornerRadius, height: 2 * cornerRadius)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(status: CloudBackupSettingsViewModel.Status) {
        switch status {
        case .disabled:
            backgroundView.fillColor = R.color.colorWaitingStatusBackground()!
            iconView.image = R.image.iconBackupDisabled()
            activityIndicator.stopAnimating()
        case .unsynced:
            backgroundView.fillColor = R.color.colorWarningBlockBackground()
            iconView.image = R.image.iconBackupUnsynced()
            activityIndicator.stopAnimating()
        case .syncing:
            backgroundView.fillColor = R.color.colorBlockBackground()!
            iconView.image = nil
            activityIndicator.startAnimating()
        case .synced:
            backgroundView.fillColor = R.color.colorActiveStatusBackground()!
            iconView.image = R.image.iconBackupSynced()
            activityIndicator.stopAnimating()
        }
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
