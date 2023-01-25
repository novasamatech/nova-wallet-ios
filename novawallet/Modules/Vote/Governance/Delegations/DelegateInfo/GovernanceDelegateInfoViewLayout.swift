import UIKit
import SoraUI

final class GovernanceDelegateInfoViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        view.stackView.spacing = 12.0
        return view
    }()

    var stackView: UIStackView {
        contentView.stackView
    }

    private var profileView: GovernanceDelegateProfileView?
    private var addressView: IdentityAccountInfoView?
    private var delegateTable: StackTableView?
    private var identityTable: StackTableView?
    private var descriptionStackView: UIStackView?
    private var descriptionView: MarkdownViewContainer?
    private var readMoreButton: RoundedButton?
    private var addDelegationButton: TriangularedButton?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func addProfileView(
        for viewModel: GovernanceDelegateProfileView.Model,
        locale: Locale
    ) -> GovernanceDelegateProfileView {
        let view: GovernanceDelegateProfileView

        if let profileView = profileView {
            view = profileView
        } else {
            let profileView = GovernanceDelegateProfileView()
            stackView.insertArrangedSubview(profileView, at: 0)
            self.profileView = profileView
            view = profileView
        }

        view.bind(viewModel: viewModel, locale: locale)

        return view
    }

    @discardableResult
    func addAddressView(for viewModel: DisplayAddressViewModel) -> IdentityAccountInfoView {
        let view: IdentityAccountInfoView

        if let addressView = addressView {
            view = addressView
        } else {
            let addressView = IdentityAccountInfoView()

            if let descriptionStackView = descriptionStackView {
                stackView.insertArranged(view: addressView, after: descriptionStackView)
            } else if let profileView = profileView {
                stackView.insertArranged(view: addressView, after: profileView)
            } else {
                stackView.insertArrangedSubview(addressView, at: 0)
            }

            stackView.addArrangedSubview(addressView)
            addressView.snp.makeConstraints { make in
                make.height.equalTo(56)
            }

            self.addressView = addressView
            view = addressView
        }

        view.bind(viewModel: viewModel)

        return view
    }

    private func createStackTableView(with title: String) -> StackTableView {
        let headerCell = StackTableHeaderCell()
        headerCell.titleLabel.text = title

        let stackTableView = StackTableView()
        stackTableView.addArrangedSubview(headerCell)

        stackTableView.setCustomHeight(32.0, at: 0)
        stackTableView.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)

        return stackTableView
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
