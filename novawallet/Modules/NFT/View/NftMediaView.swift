import UIKit
import SoraUI

final class NftMediaView: RoundedView {
    let contentView: UIImageView = {
        UIImageView()
    }()

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            if oldValue != contentInsets {
                updateLayout()
            }
        }
    }

    private var viewModel: NFTMediaViewModelProtocol?

    deinit {
        viewModel?.cancel(on: contentView)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: NFTMediaViewModelProtocol, targetSize: CGSize, cornerRadius: CGFloat) {
        self.viewModel?.cancel(on: contentView)
        contentView.image = nil

        self.viewModel = viewModel
        viewModel.loadMedia(on: contentView, targetSize: targetSize, cornerRadius: cornerRadius, animated: true)
    }

    private func updateLayout() {
        contentView.snp.updateConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }
}
