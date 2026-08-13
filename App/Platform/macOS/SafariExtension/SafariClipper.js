/**
 * SafariClipper.js — injected page script (PR38).
 *
 * Payload sent to the native handler (`SafariClipperExtension.messageReceived`):
 *   url       — document.URL
 *   title     — document.title
 *   selection — window.getSelection().toString()
 *
 * Native side maps via SafariClipFactory → CaptureInboxWriter (.loci/inbox/*.json).
 * Does not touch SQLite.
 */
(function () {
  function payload() {
    var selection = "";
    try {
      selection = window.getSelection() ? window.getSelection().toString() : "";
    } catch (ignore) {}
    return {
      url: document.URL || "",
      title: document.title || "",
      selection: selection,
    };
  }

  if (typeof safari === "undefined" || !safari.self) {
    return;
  }

  safari.self.addEventListener("message", function (event) {
    if (event.name === "extract") {
      safari.extension.dispatchMessage("clip", payload());
    }
  });
})();
