import UIKit
import UIKit_iOS

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

    let button: RoundedButton = .create { button in
        button.applyIconStyle()

        let color = R.color.colorButtonTextAccent()!
        button.imageWithTitleView?.titleColor = color
        button.imageWithTitleView?.titleFont = .caption1

        button.contentInsets = .zero
    }

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

    var buttonWidth: CGFloat = 40.0 {
        didSet {
            button.snp.updateConstraints { make in
                make.width.greaterThanOrEqualTo(buttonWidth)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        apply(style: .title)
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

        displayContentView.addSubview(button)
        button.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview()
            make.width.greaterThanOrEqualTo(buttonWidth)
        }

        displayContentView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(button.snp.leading).offset(-8)
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

    func apply(style: Style) {
        switch style {
        case .title:
            button.isHidden = true
        case .titleWithButton:
            button.isHidden = false
        }
    }
}

// MARK: LayoutStyle

extension TitleCollectionHeaderView {
    enum Style {
        case title
        case titleWithButton
    }
}
