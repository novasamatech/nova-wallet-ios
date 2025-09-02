import UIKit_iOS

class GenericBorderedView<TContentView: UIView>: UIView {
    var contentView: TContentView = .init()

    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.apply(style: .chips)
        view.cornerRadius = 6.0
        return view
    }()

    var contentInsets = UIEdgeInsets(top: 1.0, left: 8.0, bottom: 2.0, right: 8.0) {
        didSet {
            if oldValue != contentInsets {
                updateLayout()
            }
        }
    }

    var setupContentView: ((inout TContentView) -> Void)? {
        didSet {
            setupContentView?(&contentView)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateLayout() {
        contentView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
