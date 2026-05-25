//// Minimal Datadog v1 metrics client.
////
//// Create a client, build metrics, send them:
////
//// ```gleam
//// let client = datadog_client.new("DD_API_KEY")
//// datadog_client.gauge("my.metric", 1.23)
//// |> datadog_client.with_tags(["env:prod"])
//// |> datadog_client.with_host("web-01")
//// |> datadog_client.send(client, _)
//// ```

import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// HTTP host for the Datadog API. Default `datadoghq.com` (US1).
/// Use `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com`, `ap1.datadoghq.com`, etc.
pub type Client {
  Client(api_key: String, site: String)
}

pub type MetricType {
  Gauge
  Count
  Rate
}

/// A single (timestamp_seconds, value) sample.
pub type Point =
  #(Int, Float)

pub opaque type Metric {
  Metric(
    name: String,
    kind: MetricType,
    points: List(Point),
    tags: List(String),
    host: Option(String),
    interval: Option(Int),
  )
}

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
pub fn with_site(client: Client, site: String) -> Client {
  Client(..client, site: site)
}

// --- Construction -----------------------------------------------------------

/// Gauge metric at the current time.
pub fn gauge(name: String, value: Float) -> Metric {
  metric(name, Gauge, value)
}

/// Count metric at the current time.
pub fn count(name: String, value: Float) -> Metric {
  metric(name, Count, value)
}

/// Rate metric at the current time. Set the interval with `with_interval`.
pub fn rate(name: String, value: Float) -> Metric {
  metric(name, Rate, value)
}

fn metric(name: String, kind: MetricType, value: Float) -> Metric {
  Metric(
    name: name,
    kind: kind,
    points: [#(now_seconds(), value)],
    tags: [],
    host: None,
    interval: None,
  )
}

// --- Modification -----------------------------------------------------------

/// Replace the metric's tags.
pub fn with_tags(metric: Metric, tags: List(String)) -> Metric {
  Metric(..metric, tags: tags)
}

/// Append a single tag.
pub fn add_tag(metric: Metric, tag: String) -> Metric {
  Metric(..metric, tags: [tag, ..metric.tags])
}

/// Set the reporting host.
pub fn with_host(metric: Metric, host: String) -> Metric {
  Metric(..metric, host: Some(host))
}

/// Set the metric type (gauge/count/rate).
pub fn with_type(metric: Metric, kind: MetricType) -> Metric {
  Metric(..metric, kind: kind)
}

/// Set the flush interval in seconds (required for `Rate`).
pub fn with_interval(metric: Metric, seconds: Int) -> Metric {
  Metric(..metric, interval: Some(seconds))
}

/// Replace all points.
pub fn with_points(metric: Metric, points: List(Point)) -> Metric {
  Metric(..metric, points: points)
}

/// Append a single point.
pub fn add_point(metric: Metric, timestamp: Int, value: Float) -> Metric {
  Metric(..metric, points: [#(timestamp, value), ..metric.points])
}

// --- Sending ----------------------------------------------------------------

/// POST one or more metrics to `/api/v1/series`.
pub fn send(
  client: Client,
  metrics: List(Metric),
) -> Result(Response(String), SendError) {
  let body = json.to_string(encode_series(metrics))

  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> request.set_host("api." <> client.site)
    |> request.set_path("/api/v1/series")
    |> request.set_header("dd-api-key", client.api_key)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)

  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(e) { HttpError(string.inspect(e)) }),
  )

  case resp.status {
    s if s >= 200 && s < 300 -> Ok(resp)
    s -> Error(ApiError(status: s, body: resp.body))
  }
}

/// Send a single metric. Convenience over `send`.
pub fn send_one(
  client: Client,
  metric: Metric,
) -> Result(Response(String), SendError) {
  send(client, [metric])
}

// --- JSON encoding ----------------------------------------------------------

/// Serialize a list of metrics to the exact JSON body sent to `/api/v1/series`.
/// Useful for tests or buffering payloads for later submission.
pub fn encode_to_json(metrics: List(Metric)) -> String {
  json.to_string(encode_series(metrics))
}

fn encode_series(metrics: List(Metric)) -> json.Json {
  json.object([#("series", json.array(metrics, of: encode_metric))])
}

fn encode_metric(metric: Metric) -> json.Json {
  let base = [
    #("metric", json.string(metric.name)),
    #("type", json.string(type_string(metric.kind))),
    #("points", json.array(metric.points, of: encode_point)),
    #("tags", json.array(metric.tags, of: json.string)),
  ]

  let with_host = case metric.host {
    Some(h) -> [#("host", json.string(h)), ..base]
    None -> base
  }

  case metric.interval {
    Some(i) -> [#("interval", json.int(i)), ..with_host]
    None -> with_host
  }
  |> json.object
}

fn encode_point(point: Point) -> json.Json {
  let #(ts, value) = point
  json.preprocessed_array([json.int(ts), json.float(value)])
}

fn type_string(kind: MetricType) -> String {
  case kind {
    Gauge -> "gauge"
    Count -> "count"
    Rate -> "rate"
  }
}

// --- Helpers ----------------------------------------------------------------

@external(erlang, "erlang", "system_time")
fn erlang_system_time(unit: SystemTimeUnit) -> Int

type SystemTimeUnit {
  Second
}

fn now_seconds() -> Int {
  erlang_system_time(Second)
}
