// Openstage's visit counter, for a project's own website. One request per page
// view, page changes inside single-page apps included. No cookie and nothing
// stored in the browser: Openstage keeps each day's totals, not the visitor.
// https://openstage.dev/privacy
(function () {
  var script = document.currentScript
  var project = script && script.getAttribute("data-project")
  if (!project || navigator.webdriver) return
  if (location.protocol === "file:" || /^(localhost|127\.|0\.0\.0\.0|\[::1\]$)/.test(location.hostname)) return

  var endpoint = new URL(script.src).origin + "/v"
  var last = null

  function send() {
    var url = location.href.split("#")[0]
    if (url === last) return
    last = url
    var body = JSON.stringify({ p: project, u: url })
    if (navigator.sendBeacon && navigator.sendBeacon(endpoint, body)) return
    // A view that fails to send is one view uncounted; the site's console
    // should not hear about it.
    fetch(endpoint, { method: "POST", body: body, keepalive: true, mode: "no-cors", credentials: "omit" }).catch(function () {})
  }

  var pushState = history.pushState
  history.pushState = function () {
    pushState.apply(this, arguments)
    send()
  }
  window.addEventListener("popstate", send)
  send()
})()
