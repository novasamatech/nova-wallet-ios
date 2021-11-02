import UIKit

final class WalletListViewLayout: UIView {
    let backgroundView: UIImageView = {
        let view = UIImageView(image: R.image.backgroundImage())
        view.contentMode = .scaleAspectFill
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
