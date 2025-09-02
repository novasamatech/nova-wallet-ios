import UIKit

final class GenericLedgerAccountSelectionViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { label in
        label.numberOfLines = 0
        label.apply(style: .boldTitle3Primary)
    }

    private var warningView: UIView?

    private(set) var sections: [StackTableView] = []

    let loadMoreView: LoadableActionView = .create { view in
        view.actionButton.applySecondaryDefaultStyle()
        view.actionLoadingView.applyDisableButtonStyle()
    }

    var loadMoreButton: TriangularedButton { loadMoreView.actionButton }

    func clearSections() {
        sections.forEach { $0.removeFromSuperview() }
        sections = []
    }

    func addAccountSection() -> StackTableView {
        let section = StackTableView()
        section.contentInsets = UIEdgeInsets(top: 6, left: 16, bottom: 0, right: 16)
        section.cellHeight = 44

        if let lastSection = sections.last {
            containerView.stackView.setCustomSpacing(8.0, after: lastSection)
        }

        insertArrangedSubview(section, before: loadMoreView, spacingAfter: 16)

        sections.append(section)

        return section
    }

    func addAccountHeader(to section: StackTableView) -> GenericLedgerAccountStackCell {
        let headerCell = GenericLedgerAccountStackCell()

        section.addArrangedSubview(headerCell)

        section.setCustomHeight(52, at: 0)
        section.setShowsSeparator(false, at: 0)

        return headerCell
    }

    func addAddressCell(to section: StackTableView) -> GenericLedgerAddressStackCell {
        let addressCell = GenericLedgerAddressStackCell()

        section.addArrangedSubview(addressCell)

        return addressCell
    }

    func setWarning(with viewModel: TitleWithSubtitleViewModel) {
        warningView?.removeFromSuperview()
        warningView = nil

        let view = createHintView(with: viewModel)

        warningView = view

        insertArrangedSubview(view, after: titleLabel, spacingAfter: 16)
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: 16)

        addArrangedSubview(loadMoreView)
        loadMoreView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }
}

extension GenericLedgerAccountSelectionViewLayout {
    func createHintView(with viewModel: TitleWithSubtitleViewModel) -> UIView {
        let hintView = GenericBorderedView<IconDetailsGenericView<MultiValueView>>()

        hintView.contentInsets = UIEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        hintView.backgroundView.cornerRadius = 12
        hintView.backgroundView.applyFilledBackgroundStyle(
            for: R.color.colorCriticalChipBackground()!,
            highlighted: R.color.colorCriticalChipBackground()!
        )

        hintView.contentView.stackView.alignment = .top
        hintView.contentView.spacing = 12
        hintView.contentView.iconWidth = 16
        hintView.contentView.imageView.image = R.image.iconWarning()!

        hintView.contentView.detailsView.spacing = 8

        let titleLabel = hintView.contentView.detailsView.valueTop

        titleLabel.apply(style: .caption1Primary)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0

        let detailsLabel = hintView.contentView.detailsView.valueBottom
        detailsLabel.apply(style: .caption1Secondary)
        detailsLabel.textAlignment = .left
        detailsLabel.numberOfLines = 0

        hintView.contentView.detailsView.bind(
            topValue: viewModel.title,
            bottomValue: viewModel.subtitle
        )

        return hintView
    }
}
