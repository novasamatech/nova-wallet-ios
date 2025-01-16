import UIKit
import UIKit_iOS
import Foundation_iOS

final class CountdownLoadingView: UIView {
    let timerView: MultiValueView = .create { view in
        view.valueTop.apply(style: .boldTitle3Primary)
        view.valueBottom.apply(style: .caption1Secondary)
        view.valueTop.textAlignment = .center
        view.valueBottom.textAlignment = .center
        view.spacing = 0
    }

    var timerLabel: UILabel { timerView.valueTop }

    private var loadingView: LoadingView = .create { view in
        view.contentBackgroundColor = .clear
        view.indicatorImage = R.image.countdownTimerImage()
    }

    let timeUpdateAnimator = TransitionAnimator(
        type: .moveIn,
        duration: 0.25,
        subtype: .fromTop,
        curve: .easeInEaseOut
    )

    var preferredSize: CGSize {
        get {
            loadingView.contentSize
        }

        set {
            loadingView.contentSize = newValue
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: CountdownLoadingView.ViewModel, animated: Bool) {
        loadingView.startAnimating()
        timerView.valueBottom.text = viewModel.units

        updateTimeLabel(with: viewModel.duration, animated: animated)
    }

    func update(remainedTime: UInt) {
        updateTimeLabel(with: remainedTime, animated: true)
    }

    func updateAnimationOnAppear() {
        if loadingView.isAnimating {
            loadingView.stopAnimating()
            loadingView.startAnimating()
        }
    }

    private func setupStyle() {
        timerView.clipsToBounds = true
    }

    private func setupLayout() {
        addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(timerView)

        timerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(8)
        }
    }

    private func updateTimeLabel(with remainedTime: UInt, animated: Bool) {
        timerLabel.text = String(remainedTime)

        if animated {
            timeUpdateAnimator.animate(view: timerLabel, completionBlock: nil)
        }
    }
}

extension CountdownLoadingView {
    struct ViewModel {
        let duration: UInt
        let units: String
    }
}
