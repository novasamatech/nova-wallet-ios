import UIKit

class ExportNetworkView {
    let title: StackTableHeaderCell = .create { view in
        view.titleLabel.apply(style: .title3Primary)
    }

    let secretView: ExportRowView = .create { view in
        view.setContentSingleLabel()
        view.mainContentLabel.apply(style: .regularSubhedlinePrimary)
    }

    let cryptoTypeView: ExportRowView = .create { view in
        view.setContentStackedLabels()
    }

    let derivationPathView: ExportRowView = .create { view in
        view.setContentSingleLabel()
    }
}
