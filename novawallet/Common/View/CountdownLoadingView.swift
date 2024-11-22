import UIKit
import SoraUI
import SoraFoundation

final class CountdownLoadingView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.apply(style: .container)
    }

    let timerView: MultiValueView = .create { view in
        view.valueTop.apply(style: .boldTitle3Primary)
        view.valueBottom.apply(style: .caption1Secondary)
        view.valueTop.textAlignment = .center
        view.valueBottom.textAlignment = .center
        view.spacing = 0
    }

    var timerLabel: UILabel { timerView.valueTop }

    let loadingView: LoadingView = .create { view in
        view.contentBackgroundColor = .clear
        view.indicatorImage = R.image.countdownTimerImage()
    }

    let animator = TransitionAnimator(
        type: .moveIn,
        duration: 0.25,
        subtype: .fromBottom,
        curve: .easeInEaseOut
    )

    let preferredSize: CGFloat = 64

    private var timer: CountdownTimer?

    convenience init() {
        self.init(frame: .zero)
    }

    override var intrinsicContentSize: CGSize {
        .init(width: preferredSize, height: preferredSize)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start(with viewModel: ViewModel) {
        clearTimer()

        timerView.valueBottom.text = viewModel.units

        loadingView.startAnimating()

        timer = CountdownTimer(notificationInterval: 1)
        timer?.delegate = self
        timer?.start(with: TimeInterval(viewModel.duration))
    }

    func stop() {
        clearTimer()

        loadingView.stopAnimating()
    }

    private func clearTimer() {
        timer?.delegate = nil
        timer?.stop()
        timer = nil
    }

    private func setupStyle() {
        backgroundView.cornerRadius = preferredSize / 2
    }

    private func setupLayout() {
        addSubview(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(timerView)

        timerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }

    private func updateTimeLabel(with interval: TimeInterval, animated: Bool) {
        timerLabel.text = String(UInt(interval.rounded()))

        if animated {
            animator.animate(view: timerLabel, completionBlock: nil)
        }
    }
}

extension CountdownLoadingView {
    struct ViewModel {
        let duration: UInt
        let units: String
    }
}

extension CountdownLoadingView: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        updateTimeLabel(with: interval, animated: false)
    }

    func didCountdown(remainedInterval: TimeInterval) {
        updateTimeLabel(with: remainedInterval, animated: true)
    }

    func didStop(with remainedInterval: TimeInterval) {
        updateTimeLabel(with: remainedInterval, animated: true)
    }
}
