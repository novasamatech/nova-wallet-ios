browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log("Received request: ", request);

    if (request.msgType === "pub(authorize.tab)") {
        sendResponse({ type: request.msgType, content: "true" });
    } else if (request.msgType === "pub(accounts.list)") {
        sendResponse({ type: request.msgType, content: [] });
    } else if (request.msgType === "pub(metadata.list)") {
        sendResponse({ type: request.msgType, content: [] });
    } else {
        sendResponse({ type: request.msgType, content: null });
    }
});
