import SoraUI

final class GradientIconView: UIView {
    let backgroundView: MultigradientView = {
        let view = MultigradientView()
        return view
    }()

    let imageView = UIImageView()

    var contentInsets = UIEdgeInsets(top: 1.5, left: 1.5, bottom: 1.5, right: 1.5) {
        didSet {
            updateInsets()
        }
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(iconViewModel: ImageViewModelProtocol?, size: CGSize) {
        self.iconViewModel?.cancel(on: imageView)

        self.iconViewModel = iconViewModel

        imageView.image = nil
        iconViewModel?.loadImage(on: imageView, targetSize: size, animated: true)
    }

    func bind(gradient: GradientModel) {
        backgroundView.startPoint = gradient.startPoint
        backgroundView.endPoint = gradient.endPoint
        backgroundView.colors = gradient.colors
        backgroundView.locations = gradient.locations
    }

    private func updateInsets() {
        imageView.snp.updateConstraints { make in
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

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
        }
    }
}
