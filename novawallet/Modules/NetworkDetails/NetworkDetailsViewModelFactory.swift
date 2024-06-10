import SoraFoundation

class NetworkDetailsViewModelFactory {
    typealias Details = NetworkDetailsViewLayout.Model
    typealias Section = NetworkDetailsViewLayout.Section

    private let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func createViewModel(for network: ChainModel) -> Details {
        Details(
            sections: [
                createSwitchesSection(for: network),
                createAddNodeSection()
            ]
        )
    }

    func createSwitchesSection(for network: ChainModel) -> Section {
        Section(
            title: nil,
            rows: [
                .switcher(
                    .init(
                        underlyingViewModel: .init(title: "Enable connection", icon: nil),
                        selectable: network.enabled
                    )
                ),
                .switcher(
                    .init(
                        underlyingViewModel: .init(title: "Auto-balance nodes", icon: nil),
                        selectable: network.connectionMode == .autoBalanced
                    )
                )
            ]
        )
    }

    func createAddNodeSection() -> Section {
        Section(
            title: "Custom nodes",
            rows: [
                .addCustomNode(
                    .init(title: "Add custom node", icon: nil)
                )
            ]
        )
    }
}
