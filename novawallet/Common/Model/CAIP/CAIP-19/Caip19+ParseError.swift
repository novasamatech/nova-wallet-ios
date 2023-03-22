extension Caip19 {
    enum ParseError: Error, Equatable {
        case invalidAssetString
        case invalidAssetNamespace(StringCheckError)
        case invalidAssetReference(StringCheckError)
    }
}
