import UIKit

final class TitleCollectionHeaderView: UICollectionReusableView {
    private let displayContentView = UIView()

    private let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.detailsLabel.apply(style: .title3Primary)
        view.mode = .iconDetails
        view.spacing = 6.0
        view.iconWidth = 20.0
        return view
    }()

    var titleLabel: UILabel {
        titleView.detailsLabel
    }

    var iconWidth: CGFloat = 20.0 {
        didSet {
            titleView.iconWidth = iconWidth
        }
    }

    var spacing: CGFloat = 8.0 {
        didSet {
            titleView.spacing = spacing
        }
    }

    var contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            displayContentView.snp.updateConstraints { make in
                make.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(displayContentView)
        displayContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        displayContentView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.centerY.trailing.equalToSuperview()
        }
    }
}

// MARK: ViewModel

extension TitleCollectionHeaderView {
    struct Model {
        let title: String
        let icon: UIImage?
    }

    func bind(viewModel: Model) {
        titleLabel.text = viewModel.title

        if let icon = viewModel.icon {
            titleView.spacing = spacing
            titleView.iconWidth = iconWidth
            titleView.imageView.image = icon
        } else {
            titleView.spacing = 0
            titleView.iconWidth = 0
            titleView.imageView.image = nil
        }
    }

    func bind(title: String) {
        titleView.imageView.image = nil
        titleView.spacing = 0
        titleView.iconWidth = 0

        titleLabel.text = title
    }
}
