import UIKit

final class LocksHeaderView: UICollectionReusableView {
    private typealias TitleView = IconDetailsGenericView<GenericTitleValueView<UILabel, PercentView>>
    private typealias PercentView = GenericTitleValueView<BorderedLabelView, FlexibleSpaceView>

    private let view = GenericTitleValueView<TitleView, UILabel>()

    struct ViewModel {
        let icon: UIImage?
        let title: String
        let details: String
        let value: String
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0))
        }

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        view.titleView.setContentHuggingPriority(.required, for: .horizontal)
        view.valueView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        view.titleView.imageView.contentMode = .scaleAspectFill
        view.titleView.imageView.tintColor = .white
        view.titleView.detailsView.titleView.font = .regularSubheadline
        view.valueView.font = .regularSubheadline
        view.titleView.detailsView.valueView.titleView.contentInsets = .init(top: 2, left: 8, bottom: 3, right: 8)
        view.titleView.detailsView.valueView.titleView.titleLabel.textColor = R.color.colorWhite80()
    }

    func bind(viewModel: ViewModel) {
        view.titleView.imageView.image = viewModel.icon?.withRenderingMode(.alwaysTemplate)
        view.titleView.detailsView.titleView.text = viewModel.title
        view.titleView.detailsView.valueView.titleView.titleLabel.text = viewModel.details
        view.valueView.text = viewModel.value
    }
}
