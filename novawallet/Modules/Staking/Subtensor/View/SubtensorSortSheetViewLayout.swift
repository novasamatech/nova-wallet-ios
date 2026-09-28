import UIKit
import UIKit_iOS

final class SubtensorSortSheetViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.numberOfLines = 0
    }

    let optionsView = StackTableView()

    private(set) var optionViews: [SubtensorSortSheetOptionView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorSortSheetViewModel) {
        titleLabel.text = viewModel.title

        optionsView.clear()

        optionViews = viewModel.options.enumerated().map { index, option in
            let optionView = SubtensorSortSheetOptionView()
            optionView.bind(option: option, isSelected: index == viewModel.selectedIndex)
            return optionView
        }

        optionViews.forEach { optionsView.addArrangedSubview($0) }

        viewModel.options.enumerated().forEach { index, option in
            optionsView.setCustomHeight(Self.rowHeight(for: option), at: index)
        }
    }

    static func contentHeight(for viewModel: SubtensorSortSheetViewModel) -> CGFloat {
        let titleWidth = UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset

        let titleHeight = viewModel.title.boundingRect(
            with: CGSize(width: titleWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.boldTitle3],
            context: nil
        ).height

        let optionsHeight = viewModel.options.reduce(CGFloat(0)) { $0 + rowHeight(for: $1) }

        return Constants.titleTopInset + ceil(titleHeight) + Constants.optionsTopSpacing + optionsHeight +
            Constants.bottomInset
    }
}

private extension SubtensorSortSheetViewLayout {
    static func rowHeight(for option: SubtensorSortSheetViewModel.Option) -> CGFloat {
        option.subtitle == nil ? Constants.titleRowHeight : Constants.subtitleRowHeight
    }

    func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(optionsView)
        optionsView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.optionsTopSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    enum Constants {
        static let titleTopInset: CGFloat = 8
        static let optionsTopSpacing: CGFloat = 10
        static let bottomInset: CGFloat = 16
        static let titleRowHeight: CGFloat = 52
        static let subtitleRowHeight: CGFloat = 54
    }
}

final class SubtensorSortSheetOptionView: RowView<GenericTitleValueView<GenericMultiValueView<UILabel>, UIImageView>>,
    StackTableViewCellProtocol {
    var titleLabel: UILabel { rowContentView.titleView.valueTop }
    var subtitleLabel: UILabel { rowContentView.titleView.valueBottom }
    var radioView: UIImageView { rowContentView.valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    func bind(option: SubtensorSortSheetViewModel.Option, isSelected: Bool) {
        titleLabel.text = option.title
        subtitleLabel.text = option.subtitle
        subtitleLabel.isHidden = option.subtitle == nil

        radioView.image = isSelected
            ? R.image.iconRadioButtonSelected()
            : R.image.iconRadioButtonUnselected()
    }
}

private extension SubtensorSortSheetOptionView {
    func setupStyle() {
        titleLabel.apply(style: .regularBodyPrimary)
        titleLabel.textAlignment = .left

        subtitleLabel.apply(style: .caption1Secondary)
        subtitleLabel.textAlignment = .left

        radioView.contentMode = .scaleAspectFit
        radioView.snp.makeConstraints { make in
            make.size.equalTo(Constants.radioSize)
        }
    }

    enum Constants {
        static let radioSize: CGFloat = 24
    }
}
