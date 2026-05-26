import datadog_client/metric.{type Metric}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/string

@target(erlang)
import gleam/httpc
@target(erlang)
import gleam/result

@target(javascript)
import gleam/fetch
@target(javascript)
import gleam/javascript/promise.{type Promise}

/// HTTP host for the Datadog API. Default `datadoghq.com` (US1).
/// Use `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com`, `ap1.datadoghq.com`, etc.
pub type Client {
  Client(api_key: String, site: String)
}

/// Failure modes returned by `send`.
pub type SendError {
  /// Transport-level failure (DNS, TCP, TLS, etc.).
  HttpError(String)
  /// Datadog returned a non-2xx status.
  ApiError(status: Int, body: String)
}

// --- Client -----------------------------------------------------------------

/// Build a client for the default site (`datadoghq.com`).
pub fn new(api_key: String) -> Client {
  Client(api_key: api_key, site: "datadoghq.com")
}

/// Override the Datadog site (e.g. `"datadoghq.eu"`).
pub fn with_site(client: Client, to site: String) -> Client {
  Client(..client, site: site)
}

// --- Request building (transport-agnostic) ----------------------------------

/// Build the HTTPS request body for `/api/v1/series` without sending it.
/// Use this if you want to send via your own HTTP backend.
pub fn to_request(client: Client, metrics: List(Metric)) -> Request(String) {
  request.new()
  |> request.set_method(http.Post)
  |> request.set_scheme(http.Https)
  |> request.set_host("api." <> client.site)
  |> request.set_path("/api/v1/series")
  |> request.set_header("dd-api-key", client.api_key)
  |> request.set_header("content-type", "application/json")
  |> request.set_body(encode_to_json(metrics))
}

// --- Sending (Erlang via httpc) ---------------------------------------------

@target(erlang)
/// POST one or more metrics to `/api/v1/series`. Erlang target.
pub fn send(
  client: Client,
  metrics: List(Metric),
) -> Result(Response(String), SendError) {
  use resp <- result.try(
    httpc.send(to_request(client, metrics))
    |> result.map_error(fn(e) { HttpError(string.inspect(e)) }),
  )

  case resp.status {
    s if s >= 200 && s < 300 -> Ok(resp)
    s -> Error(ApiError(status: s, body: resp.body))
  }
}

@target(erlang)
/// Send a single metric. Convenience over `send`. Erlang target.
pub fn send_one(
  client: Client,
  m: Metric,
) -> Result(Response(String), SendError) {
  send(client, [m])
}

// --- Sending (JS via fetch) -------------------------------------------------

@target(javascript)
/// POST one or more metrics to `/api/v1/series`. JavaScript target.
pub fn send(
  client: Client,
  metrics: List(Metric),
) -> Promise(Result(Response(String), SendError)) {
  to_request(client, metrics)
  |> fetch.send
  |> promise.try_await(fetch.read_text_body)
  |> promise.map(fn(res) {
    case res {
      Error(e) -> Error(HttpError(string.inspect(e)))
      Ok(resp) ->
        case resp.status {
          s if s >= 200 && s < 300 -> Ok(resp)
          s -> Error(ApiError(status: s, body: resp.body))
        }
    }
  })
}

@target(javascript)
/// Send a single metric. Convenience over `send`. JavaScript target.
pub fn send_one(
  client: Client,
  m: Metric,
) -> Promise(Result(Response(String), SendError)) {
  send(client, [m])
}

// --- JSON encoding ----------------------------------------------------------

/// Serialize a list of metrics to the exact JSON body sent to `/api/v1/series`.
/// Exposed for tests and for buffering payloads for later submission.
@internal
pub fn encode_to_json(metrics: List(Metric)) -> String {
  json.object([#("series", json.array(metrics, of: metric.to_json))])
  |> json.to_string
}
