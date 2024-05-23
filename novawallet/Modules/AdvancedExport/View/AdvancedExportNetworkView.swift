import UIKit

class AdvancedExportNetworkView {
    let title: StackTableHeaderCell = .create { view in
        view.titleLabel.apply(style: .title3Primary)
    }

    let secretView: AdvancedExportRowView = .create { view in
        view.setContentSingleLabel()
        view.mainContentLabel.apply(style: .regularSubhedlinePrimary)
    }

    let cryptoTypeView: AdvancedExportRowView = .create { view in
        view.setContentStackedLabels()
    }

    let derivationPathView: AdvancedExportRowView = .create { view in
        view.setContentSingleLabel()
    }
}
