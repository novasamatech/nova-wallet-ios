import UIKit

protocol AttributedStringDecoratorProtocol: AnyObject {
    func decorate(attributedString: NSAttributedString) -> NSAttributedString
}

final class HighlightingAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let pattern: String
    let attributes: [NSAttributedString.Key: Any]
    let includeSeparator: Bool

    init(pattern: String, attributes: [NSAttributedString.Key: Any], includeSeparator: Bool = false) {
        self.pattern = pattern
        self.attributes = attributes
        self.includeSeparator = includeSeparator
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        let string = attributedString.string as NSString
        let range = string.range(of: pattern)

        guard
            range.location != NSNotFound,
            let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString
        else {
            return attributedString
        }

        resultAttributedString.addAttributes(attributes, range: range)

        if includeSeparator, range.upperBound < string.length {
            let punctuationSet = CharacterSet.punctuationCharacters
            let remainingRange = NSRange(location: range.upperBound, length: string.length - range.upperBound)
            let rangeOfPunctuation = string.rangeOfCharacter(
                from: punctuationSet,
                options: [],
                range: remainingRange
            )
            if rangeOfPunctuation.location != NSNotFound {
                resultAttributedString.addAttributes(attributes, range: rangeOfPunctuation)
            }
        }

        return resultAttributedString
    }
}

final class RangeAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let range: NSRange?
    let attributes: [NSAttributedString.Key: Any]

    init(attributes: [NSAttributedString.Key: Any], range: NSRange? = nil) {
        self.range = range
        self.attributes = attributes
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        let applicationRange = range ?? NSRange(location: 0, length: attributedString.length)

        guard let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString else {
            return attributedString
        }

        resultAttributedString.addAttributes(attributes, range: applicationRange)
        return resultAttributedString
    }
}

final class CompoundAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let decorators: [AttributedStringDecoratorProtocol]

    init(decorators: [AttributedStringDecoratorProtocol]) {
        self.decorators = decorators
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        decorators.reduce(attributedString) { result, decorator in
            decorator.decorate(attributedString: result)
        }
    }
}
