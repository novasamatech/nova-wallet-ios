import UIKit
import UIKit_iOS

final class SwapTokenSelectViewLayout: UIView {
    let grabberView: RoundedView = .create { view in
        view.shadowOpacity = 0
        view.fillColor = R.color.colorPullIndicator()!
        view.highlightedFillColor = R.color.colorPullIndicator()!
        view.cornerRadius = Constants.grabberSize.height / 2
    }

    let closeButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorChipsBackground()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorChipsBackground()!
        button.roundedBackgroundView?.cornerRadius = Constants.closeButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconClose()
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.textAlignment = .center
    }

    let searchBar: CustomSearchBar = .create { view in
        view.textFieldBackgroundView.cornerRadius = Constants.searchCornerRadius
        view.textField.autocorrectionType = .no
        view.textField.autocapitalizationType = .none
        view.textField.returnKeyType = .done
        view.textField.clearButtonMode = .always
    }

    let chipsView = SwapTokenSelectChipsView()

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.rowHeight = SwapTokenSelectTokenCell.Constants.height
        view.sectionHeaderTopPadding = 0
        view.keyboardDismissMode = .onDrag
        view.contentInset = UIEdgeInsets(top: Constants.listTopInset, left: 0, bottom: 0, right: 0)
    }

    let emptyView: SwapTokenSelectEmptyView = .create { view in
        view.isHidden = true
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
}

// MARK: Private

private extension SwapTokenSelectViewLayout {
    func setupLayout() {
        addSubview(grabberView)
        grabberView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.grabberTopInset)
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.grabberSize)
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.closeButtonTopInset)
            make.size.equalTo(Constants.closeButtonSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualTo(closeButton.snp.trailing).offset(Constants.titleHorizontalSpacing)
            make.trailing.lessThanOrEqualToSuperview().inset(Constants.titleTrailingInset)
        }

        addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.searchTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(Constants.searchHeight)
        }

        addSubview(chipsView)
        chipsView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(chipsView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(emptyView)
        emptyView.snp.makeConstraints { make in
            make.top.equalTo(chipsView.snp.bottom).offset(Constants.emptyTopOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}

// MARK: Constants

private extension SwapTokenSelectViewLayout {
    enum Constants {
        static let grabberTopInset: CGFloat = 6
        static let grabberSize = CGSize(width: 28, height: 4)
        static let closeButtonTopInset: CGFloat = 16
        static let closeButtonSize: CGFloat = 44
        static let titleHorizontalSpacing: CGFloat = 8
        static let titleTrailingInset: CGFloat = UIConstants.horizontalInset + closeButtonSize + titleHorizontalSpacing
        static let searchTopInset: CGFloat = 64
        static let searchHeight: CGFloat = 36
        static let searchCornerRadius: CGFloat = 10
        static let listTopInset: CGFloat = 4
        static let emptyTopOffset: CGFloat = 94
    }
}
