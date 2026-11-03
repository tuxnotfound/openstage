// Openstage's visit counter, for a project's own website. One request per page
// view, page changes inside single-page apps included, as long as the path
// changes: a filter or a tab in the query string keeps the page, as
// mainstream counters count it. A page load's request also carries the
// address the visitor came from. No cookie and nothing stored
// in the browser: Openstage keeps each day's totals, not the visitor.
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
    if (last !== null && url.split("?")[0] === last.split("?")[0]) return
    var view = { p: project, u: url }
    // Only a page load has a referrer of its own: later page changes in a
    // single-page app keep the one it loaded with.
    if (last === null) view.r = document.referrer
    last = url
    var body = JSON.stringify(view)
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
