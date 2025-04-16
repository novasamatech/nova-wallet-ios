import UIKit
import UIKit_iOS

class BorderedIconLabelView: UIView {
    let iconDetailsView: IconDetailsView = {
        let view = IconDetailsView()
        view.detailsLabel.numberOfLines = 0
        return view
    }()

    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.apply(style: .chips)
        view.cornerRadius = 6.0
        return view
    }()

    var contentInsets = UIEdgeInsets(top: 1.0, left: 8.0, bottom: 2.0, right: 8.0) {
        didSet {
            if oldValue != contentInsets {
                updateLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TitleIconViewModel) {
        iconDetailsView.detailsLabel.text = viewModel.title
        iconDetailsView.imageView.image = viewModel.icon
    }

    private func updateLayout() {
        iconDetailsView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.addSubview(iconDetailsView)
        iconDetailsView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
