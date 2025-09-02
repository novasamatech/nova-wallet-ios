import UIKit
import UIKit_iOS

final class BorderedImageView: UIImageView {
    let borderView: RoundedView = .create { $0.applyBorderBackgroundStyle() }

    var hidesBorder: Bool {
        get {
            borderView.isHidden
        }

        set {
            borderView.isHidden = newValue
        }
    }

    private var imageViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: .init(width: 40, height: 40)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(borderView)

        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(
        viewModel: ImageViewModelProtocol?,
        targetSize: CGSize,
        cornerRadius: CGFloat
    ) {
        imageViewModel?.cancel(on: self)

        imageViewModel = viewModel

        image = nil
        imageViewModel?.loadImage(on: self, targetSize: targetSize, cornerRadius: cornerRadius, animated: true)

        borderView.cornerRadius = cornerRadius
    }
}

extension BorderedImageView {
    private func extractIconRadius(for type: GovernanceDelegateTypeView.Model?, height: CGFloat) -> CGFloat {
        switch type {
        case .organization:
            return floor(height / 5)
        case .individual, .none:
            return height / 2
        }
    }

    func bind(
        viewModel: ImageViewModelProtocol?,
        targetSize: CGSize,
        delegateType: GovernanceDelegateTypeView.Model?
    ) {
        let radius = extractIconRadius(for: delegateType, height: targetSize.height)

        hidesBorder = delegateType == nil

        bind(viewModel: viewModel, targetSize: targetSize, cornerRadius: radius)
    }
}
