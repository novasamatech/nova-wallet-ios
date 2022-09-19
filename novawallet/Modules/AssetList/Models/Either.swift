enum Either<A, B> {
    case left(A)
    case right(B)
}

extension Either where A == B {
    var value: A {
        switch self {
        case let .left(leftItem):
            return leftItem
        case let .right(rightItem):
            return rightItem
        }
    }
}
