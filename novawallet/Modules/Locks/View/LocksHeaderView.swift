import UIKit

final class LocksHeaderView: UICollectionReusableView {
    private let view = GenericTitleValueView<IconDetailsGenericView<GenericTitleValueView<UILabel, BorderedLabelView>>, UILabel>()

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
            $0.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ViewModel) {
        view.titleView.imageView.image = viewModel.icon
        view.titleView.detailsView.titleView.text = viewModel.title
        view.titleView.detailsView.valueView.titleLabel.text = viewModel.details
        view.valueView.text = viewModel.value
    }
}
