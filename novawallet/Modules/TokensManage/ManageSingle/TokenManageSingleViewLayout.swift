import UIKit

final class TokenManageSingleViewLayout: UIView {
    let tokenView = MultichainTokenView()

    let tableView: UITableView = .create {
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tokenView)
        tokenView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(TokenManageSingleMeasurement.headerHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(tokenView.snp.bottom).offset(TokenManageSingleMeasurement.verticalSpacing)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
