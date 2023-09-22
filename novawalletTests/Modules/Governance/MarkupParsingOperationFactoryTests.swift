import XCTest
@testable import novawallet

final class MarkupParsingOperationFactoryTests: XCTestCase {

    func testMarkupParsing() throws {
        let queue = OperationQueue()
        let factory = MarkupParsingOperationFactory(
            markdownParsingOperationFactory: MarkdownParsingOperationFactory(maxSize: nil),
            htmlParsingOperationFactory: HtmlParsingOperationFactory(),
            operationQueue: queue)
        let wrapper = factory.createParseOperation(for: TestData.markupTextInput,
                                                   preferredWidth: 350)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        
        XCTAssertEqual(result?.attributedString.string, TestData.markupTextOutput)
    }
    
    func testMarkdownParsing() throws {
        let queue = OperationQueue()
        let factory = MarkupParsingOperationFactory(
            markdownParsingOperationFactory: MarkdownParsingOperationFactory(maxSize: nil),
            htmlParsingOperationFactory: HtmlParsingOperationFactory(),
            operationQueue: queue)
        let wrapper = factory.createParseOperation(for: TestData.markdownTextInput,
                                                   preferredWidth: 350)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        
        XCTAssertEqual(result?.attributedString.string, TestData.markdownTextOutput)
        
    }
    
    func testHtmlMarkdownParsing() throws {
        let queue = OperationQueue()
        let factory = MarkupParsingOperationFactory(
            markdownParsingOperationFactory: MarkdownParsingOperationFactory(maxSize: nil),
            htmlParsingOperationFactory: HtmlParsingOperationFactory(),
            operationQueue: queue)
        let wrapper = factory.createParseOperation(for: TestData.htmlWithMarkdownInput,
                                                   preferredWidth: 350)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        
        XCTAssertEqual(result?.attributedString.string, TestData.htmlWithMarkdownOutput)
        
    }

}


enum TestData {
    static var markupTextInput: String = """
This text contains an example of **Markdown** formatting usage, as well as a fragment of HTML code.
<!DOCTYPE html>
<html>
<head>
    <title>Sample HTML</title>
</head>
<body>
    <h1>This is a HTML heading</h1>
    <p>This is a paragraph of text in HTML.</p>
</body>
</html>
"""
    static var markupTextOutput: String = """
This text contains an example of Markdown formatting usage, as well as a fragment of HTML code.
Sample HTML
This is a HTML heading

This is a paragraph of text in HTML.

"""
    
    static var markdownTextInput = """
**Header 1**
This is a paragraph of regular text. You can emphasize text with *italics* or **bold**, and also create [links](https://www.example.com).
- List item 1
- List item 2
- List item 3
1. Numbered list item 1
2. Numbered list item 2
3. Numbered list item 3
"""
    
    static var markdownTextOutput = """
Header 1
This is a paragraph of regular text. You can emphasize text with italics or bold, and also create links.
  • List item 1
  • List item 2
  • List item 3
1. Numbered list item 1
2. Numbered list item 2
3. Numbered list item 3
"""
    
    static var htmlWithMarkdownInput = """
**HTML and Markdown Example**
In this example, we will combine both HTML and Markdown to format text.
Here's some **bold** and *italic* text in Markdown, within an HTML `div` element:
<div>
  This is a Markdown paragraph inside an HTML div.
  - You can create lists in Markdown.
  - Like this one.
  - And you can use HTML elements as well.
</div>
"""
    static var htmlWithMarkdownOutput = """
HTML and Markdown Example
In this example, we will combine both HTML and Markdown to format text.
Here's some bold and italic text in Markdown, within an HTML div element:
This is a Markdown paragraph inside an HTML div.
  • You can create lists in Markdown.
  • Like this one.
  • And you can use HTML elements as well.

"""
}
