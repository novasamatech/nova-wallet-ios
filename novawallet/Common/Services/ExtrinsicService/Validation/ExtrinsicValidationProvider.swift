import Foundation

protocol ExtrinsicValidationProviderProtocol {
    func getValidations(
        for view: ControllerBackedProtocol?,
        onRefresh: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating?
}
