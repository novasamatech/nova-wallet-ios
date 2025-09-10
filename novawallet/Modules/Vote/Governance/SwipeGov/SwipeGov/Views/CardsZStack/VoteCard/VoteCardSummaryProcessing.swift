import Foundation
import UIKit
import Operation_iOS
import CDMarkdownKit

struct VoteCardSummaryParams {
    let size: CGSize
}

protocol VoteCardSummaryProcessing {
    func createSummaryProcessingWrapper(
        for summaryClosure: @escaping () throws -> String,
        size: CGSize
    ) -> CompoundOperationWrapper<NSAttributedString>
}

final class VoteCardSummaryProcessor {
    let minFontSize: CGFloat = 12
    let maxFontSize: CGFloat = 40
    let normalTextColor: UIColor = R.color.colorSwipeGovSecondary()!
    let boldTextColor: UIColor = R.color.colorTextPrimary()!

    func normalFontOf(size: CGFloat) -> UIFont {
        R.font.publicSansRegular(size: size)!
    }

    func boldFontOf(size: CGFloat) -> UIFont {
        R.font.publicSansSemiBold(size: size)!
    }

    private func searchFontSize(for summary: String, size: CGSize) -> NSAttributedString {
        var fontSize = maxFontSize

        while fontSize > minFontSize {
            let attributedString = parse(summary: summary, fontSize: fontSize)

            let currentSize = attributedString.boundingRect(
                with: CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            if currentSize.height <= size.height {
                return attributedString
            } else {
                fontSize -= 1
            }
        }

        return parse(summary: summary, fontSize: fontSize)
    }

    private func parse(summary: String, fontSize: CGFloat) -> NSAttributedString {
        let parser = CDMarkdownParser(
            font: normalFontOf(size: fontSize),
            boldFont: boldFontOf(size: fontSize),
            italicFont: boldFontOf(size: fontSize),
            fontColor: normalTextColor,
            imageDetectionEnabled: false
        )

        parser.automaticLinkDetectionEnabled = false
        parser.bold.color = boldTextColor
        parser.bold.backgroundColor = nil
        parser.header.color = normalTextColor
        parser.header.backgroundColor = nil
        parser.list.color = normalTextColor
        parser.list.backgroundColor = nil
        parser.quote.color = normalTextColor
        parser.quote.backgroundColor = nil
        parser.link.color = normalTextColor
        parser.link.backgroundColor = nil
        parser.automaticLink.color = normalTextColor
        parser.automaticLink.backgroundColor = nil
        parser.italic.color = normalTextColor
        parser.italic.backgroundColor = nil
        parser.code.color = normalTextColor
        parser.syntax.color = normalTextColor
        parser.syntax.backgroundColor = nil

        return parser.parse(summary)
    }
}

extension VoteCardSummaryProcessor: VoteCardSummaryProcessing {
    func createSummaryProcessingWrapper(
        for summaryClosure: @escaping () throws -> String,
        size: CGSize
    ) -> CompoundOperationWrapper<NSAttributedString> {
        let operation = ClosureOperation {
            let summary = try summaryClosure()
            return self.searchFontSize(for: summary, size: size)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
