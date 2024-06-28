protocol NetworkNodeCreatorTrait {
    func createNode(
        with url: String,
        name: String,
        for chain: ChainModel?
    ) -> ChainNodeModel
}

extension NetworkNodeCreatorTrait {
    func createNode(
        with url: String,
        name: String,
        for chain: ChainModel?
    ) -> ChainNodeModel {
        let currentLastIndex = chain?.nodes
            .map { $0.order }
            .max()
        
        let nodeIndex: Int16 = if let currentLastIndex {
            currentLastIndex + 1
        } else {
            0
        }
        
        let node = ChainNodeModel(
            url: url,
            name: name,
            order: nodeIndex,
            features: nil,
            source: .user
        )
        
        return node
    }
}
