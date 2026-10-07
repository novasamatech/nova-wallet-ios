import UIKit
import UIKit_iOS

final class SubtensorResultSheetViewLayout: UIView {
    let contentStack: UIStackView = .create { stack in
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Constants.contentSpacing
    }

    let spinnerView: UIActivityIndicatorView = .create { view in
        view.style = .medium
        view.color = R.color.colorIconPrimary()
    }

    let tileView: RoundedView = .create { view in
        view.cornerRadius = 24
        view.shadowOpacity = 0
    }

    let tileImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
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

    let reasonLabel = UILabel(style: .caption1Primary, textAlignment: .left, numberOfLines: 0)

    let buttonsStack: UIStackView = .create { stack in
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
    }

    private let spinnerContainer = UIView()
    private let tileContainer = UIView()
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
            width: width - 2 * UIConstants.horizontalInset,
            height: UIView.layoutFittingCompressedSize.height
        )

        let contentHeight = contentStack.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let bottomHeight = buttonsStack.arrangedSubviews.isEmpty
            ? Constants.progressBottomInset
            : Constants.contentSpacing + UIConstants.actionHeight + UIConstants.actionBottomInset

        return Constants.topInset + contentHeight + bottomHeight
    }
}

private extension SubtensorResultSheetViewLayout {
    enum Constants {
        static let topInset: CGFloat = 8
        static let contentSpacing: CGFloat = 16
        static let progressBottomInset: CGFloat = 26
        static let tileSize: CGFloat = 96
        static let tileIconSize: CGFloat = 44
        static let spinnerBoxSize: CGFloat = 28
        static let reasonInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        static let reasonSpacing: CGFloat = 12
        static let reasonIconSize: CGFloat = 16
    }

    func bindGraphics(for status: SubtensorResultStatus) {
        switch status {
        case .progress:
            spinnerView.startAnimating()
        case .done:
            spinnerView.stopAnimating()
            tileImageView.image = R.image.imageSubtensorResultSuccess()
            tileIconView.image = nil
            tileView.fillColor = .clear
        case .failed:
            spinnerView.stopAnimating()
            tileImageView.image = R.image.imageSubtensorResultFailed()
            tileIconView.image = nil
            tileView.fillColor = .clear
        case .pending:
            spinnerView.stopAnimating()
            tileImageView.image = nil
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

        var views: [UIView] = if viewModel.status == .progress {
            [titleLabel, spinnerContainer, messageLabel]
        } else {
            [tileContainer, titleLabel, messageLabel]
        }

        if !viewModel.rows.isEmpty {
            views.append(rowsView)
        }

        if viewModel.reason != nil {
            views.append(reasonView)
        }

        views.forEach { contentStack.addArrangedSubview($0) }
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
        tileView.addSubview(tileImageView)
        tileImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tileView.addSubview(tileIconView)
        tileIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Constants.tileIconSize)
        }

        tileContainer.addSubview(tileView)
        tileView.snp.makeConstraints { make in
            make.top.bottom.centerX.equalToSuperview()
            make.size.equalTo(Constants.tileSize)
        }

        spinnerContainer.addSubview(spinnerView)
        spinnerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        spinnerContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.spinnerBoxSize)
        }

        let reasonContent = UIView.hStack(
            alignment: .top,
            spacing: Constants.reasonSpacing,
            [reasonIconView, reasonLabel]
        )

        reasonIconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.reasonIconSize)
        }

        reasonView.addSubview(reasonContent)
        reasonContent.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.reasonInsets)
        }

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.topInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(buttonsStack)
        buttonsStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
