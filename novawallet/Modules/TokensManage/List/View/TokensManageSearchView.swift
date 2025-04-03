import UIKit
import UIKit_iOS

class TokensManageSearchView: TopCustomSearchView {
    let zeroBalanceFilterView: GenericPairValueView<UILabel, UISwitch> = .create { view in
        view.makeHorizontal()
        view.stackView.alignment = .center

        view.fView.apply(style: .footnoteSecondary)
        view.sView.onTintColor = R.color.colorIconAccent()
    }

    var zeroBalanceFilterLabel: UILabel {
        zeroBalanceFilterView.fView
    }

    var zeroBalanceFilterSwitch: UISwitch {
        zeroBalanceFilterView.sView
    }

    override func setupLayout() {
        addSubview(blurBackgroundView)

        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.trailing.equalToSuperview().inset(16.0)
            make.height.equalTo(36.0)
        }

        addSubview(zeroBalanceFilterView)
        zeroBalanceFilterView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(searchBar.snp.bottom).offset(5)
            make.bottom.equalToSuperview().inset(6)
            make.height.equalTo(44)
        }
    }
}
