import UIKit
import UIKit_iOS

final class DAppIconView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.apply(style: .container)
        return view
    }()

    let imageView = UIImageView()

    var contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16) {
        didSet {
            updateInsets()
        }
    }

    private var viewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ImageViewModelProtocol?, size: CGSize) {
        self.viewModel?.cancel(on: imageView)

        self.viewModel = viewModel

        imageView.image = nil

        if contentInsets == .zero {
            updateInsets(for: size)
        }

        viewModel?.loadImage(on: imageView, targetSize: size, animated: true)
    }

    private func updateInsets(for iconSize: CGSize) {
        let edgeInset = (DAppIconCellConstants.size.width - iconSize.width) / 2

        imageView.snp.updateConstraints { make in
            make.top.equalToSuperview().inset(edgeInset)
            make.bottom.equalToSuperview().inset(edgeInset)
            make.leading.equalToSuperview().inset(edgeInset)
            make.trailing.equalToSuperview().inset(edgeInset)
        }
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

enum DAppIconCellConstants {
    static let size = CGSize(width: 48.0, height: 48.0)
}

enum DAppIconLargeConstants {
    static let size = CGSize(width: 88.0, height: 88.0)
    static let insets = UIEdgeInsets(top: 11.0, left: 11.0, bottom: 11.0, right: 11.0)
    static var displaySize: CGSize {
        CGSize(
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
    }
}
