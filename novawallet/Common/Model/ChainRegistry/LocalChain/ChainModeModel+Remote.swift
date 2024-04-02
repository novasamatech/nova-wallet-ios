import Foundation

extension ChainNodeModel {
    init(remoteModel: RemoteChainNodeModel, order: Int16) {
        url = remoteModel.url
        name = remoteModel.name
        self.order = order
        features = remoteModel.features.flatMap { Set($0.compactMap { Feature(rawValue: $0) }) }
    }
}
