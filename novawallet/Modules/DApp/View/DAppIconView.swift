import UIKit
import SoraUI

final class DAppIconView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.shadowOpacity = 0
        view.fillColor = R.color.colorWhite8()!
        view.highlightedFillColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
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
        viewModel?.loadImage(on: imageView, targetSize: size, animated: true)
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
