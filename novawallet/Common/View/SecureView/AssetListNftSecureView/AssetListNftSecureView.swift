import Foundation
import UIKit

final class AssetListNftSecureView<View: UIView>: UIView {
    var preferredSecuredHeight: CGFloat? {
        imageSecureView.preferredSecuredHeight
    }

    var originalView: View {
        imageSecureView.originalView
    }

    private lazy var imageSecureView: ImageSecureView<View> = {
        createImageSecureView()
    }()

    private let displayIndex: Int
    private let placeholderFactory = NftSecureImageFactory()

    init(displayIndex: Int) {
        self.displayIndex = displayIndex

        super.init(frame: .zero)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension AssetListNftSecureView {
    func setupLayout() {
        addSubview(imageSecureView)
        imageSecureView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func createImageSecureView() -> ImageSecureView<View> {
        let view = ImageSecureView<View> { [weak self] in
            guard let self else { return nil }

            return placeholderFactory.createPlaceholder(for: displayIndex)
        }

        view.overlayConfiguration = .shadowedNft

        return view
    }
}

// MARK: - Internal

extension AssetListNftSecureView {
    func bind(_ privacyMode: ViewPrivacyMode) {
        imageSecureView.bind(privacyMode)
    }
}
