import Foundation

protocol SectionProtocol {
    associatedtype CellModel
    var cells: [CellModel] { get set }
}
