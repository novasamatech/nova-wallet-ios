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
    private var statsTable: StackTableView?
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
            let profileView = GovernanceDelegateProfileView(size: CGSize(width: 64, height: 64))
            stackView.insertArrangedSubview(profileView, at: 0)
            self.profileView = profileView
            view = profileView
        }

        view.locale = locale

        view.bind(viewModel: viewModel)

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

    func addDescription(from viewModel: GovernanceDelegateInfoViewModel.Delegate, locale _: Locale) -> RoundedButton? {
        if descriptionStackView != nil {
            descriptionStackView?.removeFromSuperview()
            descriptionStackView = nil
        }

        let optDescriptionView: MarkdownViewContainer?

        if let details = viewModel.details {
            optDescriptionView = MarkdownViewContainer(
                preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
            )

            optDescriptionView?.load(from: details, completion: nil)
        } else {
            optDescriptionView = nil
        }

        descriptionView = optDescriptionView

        let optReadMoreButton: RoundedButton?

        if viewModel.hasFullDescription {
            optReadMoreButton = RoundedButton()
            optReadMoreButton?.applyLinkStyle()
        } else {
            optReadMoreButton = nil
        }

        readMoreButton = optReadMoreButton

        if let descriptionView = optDescriptionView, let readMoreButton = optReadMoreButton {
            descriptionStackView = UIView.vStack(spacing: 8, [
                descriptionView,
                UIView.hStack([
                    readMoreButton,
                    UIView()
                ])
            ])
        } else if let descriptionView = optDescriptionView {
            descriptionStackView = UIView.vStack([descriptionView])
        } else if let readMoreButton = optReadMoreButton {
            descriptionStackView = UIView.hStack([
                readMoreButton,
                UIView()
            ])
        }

        if let descriptionStackView = descriptionStackView {
            if let profileView = profileView {
                stackView.insertArranged(view: descriptionStackView, after: profileView)
            } else {
                stackView.insertSubview(descriptionStackView, at: 0)
            }
        }

        return optReadMoreButton
    }

    @discardableResult
    func addStatsTable(for locale: Locale) -> StackTableView {
        if statsTable != nil {
            statsTable?.removeFromSuperview()
            statsTable = nil
        }

        let table = createStackTableView(
            with: R.string.localizable.delegationsTitle(preferredLanguages: locale.rLanguages)
        )

        if let identityTable = identityTable {
            stackView.insertArranged(view: table, before: identityTable)
        }

        statsTable = table

        return table
    }

    @discardableResult
    func addIdentityTable(for locale: Locale) -> StackTableView {
        if identityTable != nil {
            identityTable?.removeFromSuperview()
            identityTable = nil
        }

        let table = createStackTableView(
            with: R.string.localizable.identityTitle(preferredLanguages: locale.rLanguages)
        )

        stackView.addArrangedSubview(table)

        identityTable = table

        return table
    }

    func addDelegationButton(for locale: Locale) -> TriangularedButton? {
        if addDelegationButton == nil {
            let button = TriangularedButton()
            button.applyDefaultStyle()

            addSubview(button)

            button.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
                make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            }

            addDelegationButton = button
        }

        addDelegationButton?.imageWithTitleView?.title = R.string.localizable.governanceReferendumsAddDelegation(
            preferredLanguages: locale.rLanguages
        )

        updateContentInsets()

        return addDelegationButton
    }

    func removeDelegationButton() {
        addDelegationButton?.removeFromSuperview()
        addDelegationButton = nil

        updateContentInsets()
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

    private func updateContentInsets() {
        if addDelegationButton != nil {
            contentView.scrollView.contentInset = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: UIConstants.actionBottomInset + UIConstants.actionHeight,
                right: 0
            )
        } else {
            contentView.scrollView.contentInset = .zero
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
