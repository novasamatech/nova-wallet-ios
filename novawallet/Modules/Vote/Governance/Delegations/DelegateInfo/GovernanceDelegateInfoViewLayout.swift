import UIKit
import UIKit_iOS

final class GovernanceDelegateInfoViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        return view
    }()

    var stackView: UIStackView {
        contentView.stackView
    }

    private var profileView: GovernanceDelegateProfileView?
    private var addressView: IdentityAccountInfoView?
    private var statsTable: StackTableView?
    private var yourDelegationTable: StackTableView?
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
            stackView.setCustomSpacing(16, after: profileView)

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
            addressView.actionIcon = R.image.iconMore()?.withTintColor(R.color.colorIconSecondary()!)
            if let descriptionStackView = descriptionStackView {
                stackView.insertArranged(view: addressView, after: descriptionStackView)
            } else if let profileView = profileView {
                stackView.insertArranged(view: addressView, after: profileView)
            } else {
                stackView.insertArrangedSubview(addressView, at: 0)
            }

            stackView.setCustomSpacing(8, after: addressView)

            addressView.snp.makeConstraints { make in
                make.height.equalTo(56)
            }

            self.addressView = addressView
            view = addressView
        }

        view.bind(viewModel: viewModel)

        return view
    }

    func addDescription(
        from viewModel: GovernanceDelegateInfoViewModel.Delegate,
        delegate: MarkdownViewContainerDelegate?,
        locale: Locale
    ) -> RoundedButton? {
        if
            let details = viewModel.details,
            descriptionView != nil,
            viewModel.hasFullDescription,
            readMoreButton != nil {
            // if structure doesn't change then reload text
            descriptionView?.load(from: details, completion: nil)
            descriptionView?.delegate = delegate

            return readMoreButton
        } else {
            descriptionStackView?.removeFromSuperview()
            descriptionStackView = nil

            return createDescription(from: viewModel, delegate: delegate, locale: locale)
        }
    }

    private func createDescription(
        from viewModel: GovernanceDelegateInfoViewModel.Delegate,
        delegate: MarkdownViewContainerDelegate?,
        locale: Locale
    ) -> RoundedButton? {
        let optDescriptionView: MarkdownViewContainer?

        if let details = viewModel.details {
            optDescriptionView = MarkdownViewContainer(
                preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset,
                maxTextLength: MarkupAttributedText.readMoreThreshold
            )

            optDescriptionView?.load(from: details, completion: nil)
        } else {
            optDescriptionView = nil
        }

        descriptionView = optDescriptionView
        descriptionView?.delegate = delegate

        let optReadMoreButton: RoundedButton?

        if viewModel.hasFullDescription {
            optReadMoreButton = RoundedButton()
            optReadMoreButton?.applyLinkStyle()
            optReadMoreButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonReadMore()
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

            stackView.setCustomSpacing(24, after: descriptionStackView)
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
            with: R.string(preferredLanguages: locale.rLanguages).localizable.delegationsDelegations()
        )

        if let identityTable = identityTable {
            stackView.insertArranged(view: table, before: identityTable)
        } else {
            stackView.addArrangedSubview(table)
        }

        stackView.setCustomSpacing(8, after: table)

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
            with: R.string(preferredLanguages: locale.rLanguages).localizable.identityTitle()
        )

        stackView.addArrangedSubview(table)

        identityTable = table

        return table
    }

    @discardableResult
    func addYourDelegationTable(for locale: Locale) -> StackTableView {
        removeYourDelegationTable()

        let table = createStackTableView(
            with: R.string(preferredLanguages: locale.rLanguages).localizable.govYourDelegation()
        )

        if let nextView = statsTable ?? identityTable {
            stackView.insertArranged(view: table, before: nextView)
        } else {
            stackView.addArrangedSubview(table)
        }

        stackView.setCustomSpacing(8, after: table)

        yourDelegationTable = table

        return table
    }

    func removeYourDelegationTable() {
        yourDelegationTable?.removeFromSuperview()
        yourDelegationTable = nil
    }

    func addTracksCell(for viewModel: GovernanceTracksViewModel, locale: Locale) -> StackInfoTableCell? {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.govTracks()

        if viewModel.canExpand {
            return yourDelegationTable?.addInfoCell(for: title, value: viewModel.details)
        } else {
            yourDelegationTable?.addTitleValueCell(for: title, value: viewModel.details)
            return nil
        }
    }

    func addYourDelegationCell(for viewModel: GovernanceYourDelegationViewModel, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.govYourDelegation()

        let cell = yourDelegationTable?.addTitleMultiValue(
            for: title,
            valueTop: viewModel.votes,
            valueBottom: viewModel.conviction
        )

        cell?.canSelect = false
    }

    func addYourDelegationActions(for locale: Locale) -> StackButtonsCell {
        let cell = StackButtonsCell()

        cell.mainButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.commonEdit()

        cell.secondaryButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.commonRevoke()

        yourDelegationTable?.addArrangedSubview(cell)

        if let index = yourDelegationTable?.stackView.arrangedSubviews.firstIndex(of: cell) {
            yourDelegationTable?.setShowsSeparator(false, at: index)

            if index > 0 {
                yourDelegationTable?.setShowsSeparator(false, at: index - 1)
            }

            yourDelegationTable?.setCustomHeight(76, at: index)
        }

        cell.contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        return cell
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

        addDelegationButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.delegationsAddTitle()

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
