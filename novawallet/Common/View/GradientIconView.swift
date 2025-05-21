import UIKit_iOS

class GenericGradientBackgroundView<TView: UIView>: UIView {
    let backgroundView = MultigradientView()

    let titleView = TView()

    var contentInsets = UIEdgeInsets(top: 1.5, left: 1.5, bottom: 1.5, right: 1.5) {
        didSet {
            updateInsets()
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

    func bind(gradient: GradientModel) {
        backgroundView.startPoint = gradient.startPoint
        backgroundView.endPoint = gradient.endPoint
        backgroundView.colors = gradient.colors
        backgroundView.locations = gradient.locations
    }

    private func updateInsets() {
        titleView.snp.updateConstraints { make in
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
        }
    }
}

typealias GradientIconDetailsView = GenericGradientBackgroundView<IconDetailsView>
