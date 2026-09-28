import UIKit

struct SubtensorSortSheetViewModel {
    struct Option {
        let title: String
        let subtitle: String?
    }

    let title: String
    let options: [Option]
    let selectedIndex: Int?
}

final class SubtensorSortSheetViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSortSheetViewLayout

    private let viewModel: SubtensorSortSheetViewModel
    private let onSelect: (Int) -> Void

    init(viewModel: SubtensorSortSheetViewModel, onSelect: @escaping (Int) -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect

        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(
            width: 0,
            height: SubtensorSortSheetViewLayout.contentHeight(for: viewModel)
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorSortSheetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.bind(viewModel: viewModel)
        setupHandlers()
    }
}

private extension SubtensorSortSheetViewController {
    func setupHandlers() {
        rootView.optionViews.forEach { optionView in
            optionView.addTarget(self, action: #selector(actionSelectOption(_:)), for: .touchUpInside)
        }
    }

    @objc func actionSelectOption(_ sender: UIControl) {
        guard let index = rootView.optionViews.firstIndex(where: { $0 === sender }) else {
            return
        }

        let onSelect = onSelect

        view.isUserInteractionEnabled = false

        dismiss(animated: true) {
            onSelect(index)
        }
    }
}
