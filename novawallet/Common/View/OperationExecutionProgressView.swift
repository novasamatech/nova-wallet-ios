import UIKit
import UIKit_iOS

final class OperationExecutionProgressView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.apply(style: .container)
    }

    let preferredSize: CGFloat = 64

    private var loadingView: CountdownLoadingView?
    private var finalStatusView: UIImageView?

    private var currentViewModel: OperationExecutionProgressView.ViewModel?

    override var intrinsicContentSize: CGSize {
        .init(width: preferredSize, height: preferredSize)
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

    func bind(viewModel: OperationExecutionProgressView.ViewModel) {
        if
            let currentViewModel,
            currentViewModel.isInProgress,
            case let .inProgress(inProgress) = viewModel {
            self.currentViewModel = viewModel

            loadingView?.bind(viewModel: inProgress, animated: true)

            return
        }

        currentViewModel = viewModel

        clearCurrentStatusView()

        switch viewModel {
        case let .inProgress(viewModel):
            setupLoadingView()
            loadingView?.bind(viewModel: viewModel, animated: false)
        case .completed:
            setupFinalStatusView(isComplete: true)
        case .failed:
            setupFinalStatusView(isComplete: false)
        }
    }

    func updateProgress(remainedTime: UInt) {
        guard let currentViewModel, currentViewModel.isInProgress else { return }

        loadingView?.update(remainedTime: remainedTime)
    }

    func updateAnimationOnAppear() {
        loadingView?.updateAnimationOnAppear()
    }

    private func setupStyle() {
        backgroundView.cornerRadius = preferredSize / 2
    }

    private func setupLayout() {
        addSubview(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func clearCurrentStatusView() {
        loadingView?.removeFromSuperview()
        loadingView = nil

        finalStatusView?.removeFromSuperview()
        finalStatusView = nil
    }

    private func setupLoadingView() {
        let view = CountdownLoadingView()
        view.preferredSize = CGSize(width: preferredSize, height: preferredSize)
        configureContent(view: view)

        loadingView = view
    }

    private func setupFinalStatusView(isComplete: Bool) {
        let image = isComplete ? R.image.iconSwapExecutionComplete() : R.image.iconSwapExecutionFailed()
        let view = UIImageView(image: image)

        configureContent(view: view)

        finalStatusView = view
    }

    private func configureContent(view: UIView) {
        addSubview(view)

        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension OperationExecutionProgressView {
    enum ViewModel {
        case inProgress(CountdownLoadingView.ViewModel)
        case completed
        case failed

        var isInProgress: Bool {
            switch self {
            case .inProgress: return true
            case .completed, .failed: return false
            }
        }
    }
}
