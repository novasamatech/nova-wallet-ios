import UIKit

final class CrowdloanEmptyView: UIView {
    
    var verticalSpacing: CGFloat = 8.0 {
        didSet {
            stackView.spacing = verticalSpacing
        }
    }

    let imageView = UIImageView()

    let titleLabel: UILabel = .create {
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.backgroundColor = .clear
        $0.textColor = R.color.colorLightGray()!
        $0.font = .p2Paragraph
    }

    private lazy var stackView = UIStackView(arrangedSubviews: [
        imageView,
        titleLabel
    ])

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        stackView.axis = .vertical
        stackView.alignment = .center

        addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(image: UIImage?, text: String?) {
        imageView.image = image
        titleLabel.text = text
    }
}

