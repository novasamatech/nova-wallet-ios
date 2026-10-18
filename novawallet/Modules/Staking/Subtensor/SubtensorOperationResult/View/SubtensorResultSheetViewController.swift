import UIKit
import UIKit_iOS

final class SubtensorResultSheetViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorResultSheetViewLayout

    let presenter: SubtensorResultPresenterProtocol

    private var actions: [SubtensorResultAction] = []

    init(presenter: SubtensorResultPresenterProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorResultSheetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

private extension SubtensorResultSheetViewController {
    func updatePreferredHeight() {
        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width

        preferredContentSize = CGSize(width: 0, height: rootView.preferredHeight(for: width))

        guard
            view.window != nil,
            let presentationController,
            let containerView = presentationController.containerView else {
            return
        }

        UIView.animate(withDuration: 0.25) {
            self.view.frame = presentationController.frameOfPresentedViewInContainerView
            containerView.layoutIfNeeded()
        }
    }

    @objc func actionButton(_ sender: UIButton) {
        guard actions.indices.contains(sender.tag) else {
            return
        }

        presenter.activate(action: actions[sender.tag])
    }
}

extension SubtensorResultSheetViewController: SubtensorResultViewProtocol {
    func didReceive(viewModel: SubtensorOperationResultViewModel) {
        guard case let .sheet(sheetViewModel) = viewModel else {
            return
        }

        actions = sheetViewModel.actions.map(\.action)

        let buttons = rootView.bind(viewModel: sheetViewModel)

        for (index, button) in buttons.enumerated() {
            button.tag = index
            button.addTarget(self, action: #selector(actionButton(_:)), for: .touchUpInside)
        }

        updatePreferredHeight()
    }

    func didUpdateCountdown(remainedTime _: UInt) {}
}

extension SubtensorResultSheetViewController: ModalSheetPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool {
        false
    }

    func presenterDidHide(_: ModalPresenterProtocol) {}

    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        false
    }
}

extension ModalSheetPresentationConfiguration {
    static var subtensorResultSheet: ModalSheetPresentationConfiguration {
        let headerStyle = ModalSheetPresentationHeaderStyle(
            preferredHeight: 20.0,
            backgroundColor: R.color.colorBottomSheetBackground()!,
            cornerRadius: 16.0,
            indicatorVerticalOffset: 4.0,
            indicatorSize: CGSize(width: 32.0, height: 3.0),
            indicatorColor: .clear
        )

        let style = ModalSheetPresentationStyle(
            sizing: .manual,
            backdropColor: R.color.colorDimBackground()!,
            headerStyle: headerStyle
        )

        return ModalSheetPresentationConfiguration(
            contentAppearanceAnimator: BlockViewAnimator(duration: 0.25, delay: 0.0, options: [.curveEaseOut]),
            contentDissmisalAnimator: BlockViewAnimator(duration: 0.25, delay: 0.0, options: [.curveLinear]),
            style: style,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
        )
    }
}
