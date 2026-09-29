import UIKit
import UIKit_iOS

final class SubtensorResultSheetViewLayout: UIView {
    let contentStack: UIStackView = .create { stack in
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
    }

    let spinnerView: UIActivityIndicatorView = .create { view in
        view.style = .medium
        view.color = R.color.colorIconPrimary()
    }

    let tileView: RoundedView = .create { view in
        view.cornerRadius = 24
        view.shadowOpacity = 0
    }

    let tileIconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel = UILabel(style: .boldTitle3Primary, textAlignment: .center, numberOfLines: 0)

    let messageLabel = UILabel(style: .regularSubhedlineSecondary, textAlignment: .center, numberOfLines: 0)

    let rowsView = StackTableView()

    let reasonView: RoundedView = .create { view in
        view.applyErrorBlockBackgroundStyle()
        view.cornerRadius = 12
    }

    let reasonLabel = UILabel(style: .footnotePrimary, textAlignment: .left, numberOfLines: 0)

    let buttonsStack: UIStackView = .create { stack in
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
    }

    private lazy var spinnerContainer = UIView.hStack(alignment: .center, [UIView(), spinnerView, UIView()])
    private lazy var tileContainer = UIView.hStack(alignment: .center, [UIView(), tileView, UIView()])
    private lazy var reasonIconView: UIImageView = .create { view in
        view.image = R.image.iconErrorFilled()
        view.contentMode = .scaleAspectFit
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorResultSheetViewModel) -> [TriangularedButton] {
        titleLabel.text = viewModel.title
        messageLabel.text = viewModel.message
        reasonLabel.text = viewModel.reason

        bindGraphics(for: viewModel.status)
        bindRows(viewModel.rows)
        arrangeContent(for: viewModel)

        return bindButtons(viewModel.actions)
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        let fittingSize = CGSize(
            width: width - 2 * Constants.sideInset,
            height: UIView.layoutFittingCompressedSize.height
        )

        let contentHeight = contentStack.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let buttonsHeight = buttonsStack.arrangedSubviews.isEmpty ? 0 : Constants.buttonsSpacing +
            UIConstants.actionHeight

        return Constants.topInset + contentHeight + buttonsHeight + Constants.bottomInset
    }
}

private extension SubtensorResultSheetViewLayout {
    enum Constants {
        static let sideInset: CGFloat = 16
        static let topInset: CGFloat = 16
        static let bottomInset: CGFloat = 16
        static let buttonsSpacing: CGFloat = 24
        static let tileSize: CGFloat = 88
        static let tileIconSize: CGFloat = 48
    }

    func bindGraphics(for status: SubtensorResultStatus) {
        switch status {
        case .progress:
            spinnerView.startAnimating()
        case .done:
            spinnerView.stopAnimating()
            tileIconView.image = R.image.iconSwapExecutionComplete()
            tileView.fillColor = R.color.colorIconPositive()!.withAlphaComponent(0.16)
        case .failed:
            spinnerView.stopAnimating()
            tileIconView.image = R.image.iconSwapExecutionFailed()
            tileView.fillColor = R.color.colorIconNegative()!.withAlphaComponent(0.16)
        case .pending:
            spinnerView.stopAnimating()
            tileIconView.image = R.image.iconPending()
            tileView.fillColor = R.color.colorBlockBackground()!
        }

        tileView.highlightedFillColor = tileView.fillColor
    }

    func bindRows(_ rows: [SubtensorResultSheetRowViewModel]) {
        rowsView.clear()

        for row in rows {
            if let fiat = row.fiat {
                let cell = StackTitleMultiValueCell()
                cell.canSelect = false
                cell.titleLabel.text = row.title
                cell.topValueLabel.text = row.value
                cell.bottomValueLabel.text = fiat
                rowsView.addArrangedSubview(cell)
            } else {
                let cell = StackTableCell()
                cell.titleLabel.text = row.title
                cell.bind(details: row.value)
                rowsView.addArrangedSubview(cell)
            }
        }
    }

    func arrangeContent(for viewModel: SubtensorResultSheetViewModel) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let views: [UIView] = if viewModel.status == .progress {
            [titleLabel, spinnerContainer, messageLabel]
        } else {
            [tileContainer, titleLabel, messageLabel]
        }

        views.forEach { contentStack.addArrangedSubview($0) }

        if viewModel.status == .progress {
            contentStack.setCustomSpacing(16, after: titleLabel)
            contentStack.setCustomSpacing(16, after: spinnerContainer)
        } else {
            contentStack.setCustomSpacing(24, after: tileContainer)
            contentStack.setCustomSpacing(8, after: titleLabel)
        }

        if !viewModel.rows.isEmpty {
            contentStack.setCustomSpacing(16, after: messageLabel)
            contentStack.addArrangedSubview(rowsView)
        }

        if viewModel.reason != nil {
            contentStack.setCustomSpacing(16, after: messageLabel)
            contentStack.addArrangedSubview(reasonView)
        }
    }

    func bindButtons(_ actions: [SubtensorResultActionViewModel]) -> [TriangularedButton] {
        buttonsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttonsStack.isHidden = actions.isEmpty

        return actions.enumerated().map { index, action in
            let button = TriangularedButton()

            if index == actions.count - 1 {
                button.applyDefaultStyle()
            } else {
                button.applySecondaryDefaultStyle()
            }

            button.imageWithTitleView?.title = action.title
            buttonsStack.addArrangedSubview(button)

            return button
        }
    }

    func setupLayout() {
        tileView.addSubview(tileIconView)
        tileIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Constants.tileIconSize)
        }

        tileView.snp.makeConstraints { make in
            make.size.equalTo(Constants.tileSize)
        }

        let reasonContent = UIView.hStack(alignment: .top, spacing: 8, [reasonIconView, reasonLabel])
        reasonIconView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        reasonView.addSubview(reasonContent)
        reasonContent.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.topInset)
            make.leading.trailing.equalToSuperview().inset(Constants.sideInset)
        }

        addSubview(buttonsStack)
        buttonsStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.sideInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Constants.bottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
