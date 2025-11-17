import UIKit

final class GiftListViewLayout: UIView {
    lazy var onboardingView = GiftsOnboardingView()

    let loadingView = ListLoadingView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupInitialLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension GiftListViewLayout {
    func setupInitialLayout() {
        layoutLoadingView()
    }

    // MARK: - Loading

    func layoutLoadingView() {
        guard loadingView.superview == nil else { return }

        addSubview(loadingView)
        loadingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func applyLoading() {
        layoutLoadingView()
        loadingView.start()
    }

    func stopLoading() {
        loadingView.stop()
        loadingView.removeFromSuperview()
    }

    // MARK: - Onboarding

    func layoutOnboarding() {
        guard onboardingView.superview == nil else { return }

        addSubview(onboardingView)
        onboardingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func applyOnboarding(viewModel: GiftsOnboardingViewModel) {
        layoutOnboarding()
        onboardingView.bind(viewModel: viewModel)
    }

    func removeOnboarding() {
        onboardingView.removeFromSuperview()
    }
}

// MARK: - Internal

extension GiftListViewLayout {
    func bind(loading: Bool) {
        if loading { applyLoading() }
        else { stopLoading() }
    }

    func bind(contentModel: ContentModel) {
        switch contentModel {
        case let .onboarding(viewModel):
            applyOnboarding(viewModel: viewModel)
        case .list:
            removeOnboarding()
        }
    }
}

extension GiftListViewLayout {
    enum ContentModel {
        case onboarding(GiftsOnboardingViewModel)
        case list
    }
}
