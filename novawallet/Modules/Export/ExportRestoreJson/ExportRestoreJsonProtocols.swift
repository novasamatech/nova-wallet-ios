import Foundation

protocol ExportRestoreJsonWireframeProtocol: ExportGenericWireframeProtocol {}

protocol ExportRestoreJsonViewFactoryProtocol {
    static func createView(with model: RestoreJson) -> ExportGenericViewProtocol?
}
