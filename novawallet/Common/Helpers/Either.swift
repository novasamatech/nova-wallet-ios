// https://github.com/apple/swift/blob/main/stdlib/public/core/EitherSequence.swift
enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

extension Either where Left == Right {
    var value: Left {
        switch self {
        case let .left(left):
            return left
        case let .right(right):
            return right
        }
    }
}
