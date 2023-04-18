protocol Web3NameAddressListPresentable {
    func presentWeb3NameAddressListPicker(
        from view: ControllerBackedProtocol,
        viewModel: Web3NameAddressListViewModel,
        delegate: ModalPickerViewControllerDelegate?
    )
}

extension Web3NameAddressListPresentable {
    func presentWeb3NameAddressListPicker(
        from view: ControllerBackedProtocol,
        viewModel: Web3NameAddressListViewModel,
        delegate: ModalPickerViewControllerDelegate?
    ) {
        guard let pickerView = ModalPickerFactory.createSelectableAddressesList(
            title: viewModel.title,
            items: viewModel.items,
            selectedIndex: viewModel.selectedIndex,
            delegate: delegate,
            context: viewModel.context
        )
        else {
            return
        }

        view.controller.present(pickerView, animated: true)
    }
}
