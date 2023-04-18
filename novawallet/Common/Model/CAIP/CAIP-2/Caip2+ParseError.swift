extension Caip2 {
    enum ParseError: Error, Equatable {
        case invalidInputString
        case invalidNamespace(StringCheckError)
        case invalidReference(StringCheckError)
    }
}
