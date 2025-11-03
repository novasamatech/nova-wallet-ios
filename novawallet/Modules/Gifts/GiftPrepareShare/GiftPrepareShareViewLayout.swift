import UIKit
import Lottie

final class GiftPrepareShareViewLayout: UIView {
    let animationView = LottieAnimationView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension GiftPrepareShareViewLayout {
    func setupLayout() {
        addSubview(animationView)
        animationView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(280)
        }
    }
}

extension GiftPrepareShareViewLayout {
    func bind(viewModel: GiftPrepareViewModel) {
        animationView.animation = viewModel.animation
        animationView.play()
    }
}
