import datadog_client/common
import gleam/json
import gleam/option.{type Option}

/// A single sample: a Unix timestamp in seconds and its value.
pub type Point {
  Point(timestamp: Int, value: Float)
}

/// Datadog metric kind.
pub type MetricType {
  Gauge
  Count
  Rate
}

/// A Datadog series entry. Build with `gauge`/`count`/`rate` and refine via
/// the `with_*` / `add_*` helpers.
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

// --- Construction -----------------------------------------------------------

/// Gauge metric at the current time.
pub fn gauge(name: String, value: Float) -> Metric {
  build(name, Gauge, value)
}

/// Count metric at the current time.
pub fn count(name: String, value: Float) -> Metric {
  build(name, Count, value)
}

/// Rate metric at the current time. Set the interval with `with_interval`.
pub fn rate(name: String, value: Float) -> Metric {
  build(name, Rate, value)
}

fn build(name: String, kind: MetricType, value: Float) -> Metric {
  Metric(
    name: name,
    kind: kind,
    points: [Point(timestamp: common.now_seconds(), value: value)],
    tags: [],
    host: option.None,
    interval: option.None,
  )
}

// --- Modification -----------------------------------------------------------

/// Replace the metric's tags.
pub fn with_tags(metric: Metric, with tags: List(String)) -> Metric {
  Metric(..metric, tags: tags)
}

/// Append a single tag.
pub fn add_tag(metric: Metric, with tag: String) -> Metric {
  Metric(..metric, tags: [tag, ..metric.tags])
}

/// Set the reporting host.
pub fn with_host(metric: Metric, to host: String) -> Metric {
  Metric(..metric, host: option.Some(host))
}

/// Set the metric type (gauge/count/rate).
pub fn with_type(metric: Metric, to kind: MetricType) -> Metric {
  Metric(..metric, kind: kind)
}

/// Set the flush interval in seconds (required for `Rate`).
pub fn with_interval(metric: Metric, of seconds: Int) -> Metric {
  Metric(..metric, interval: option.Some(seconds))
}

/// Replace all points.
pub fn with_points(metric: Metric, with points: List(Point)) -> Metric {
  Metric(..metric, points: points)
}

/// Append a single point at the given timestamp.
pub fn add_point(metric: Metric, at timestamp: Int, of value: Float) -> Metric {
  Metric(..metric, points: [
    Point(timestamp: timestamp, value: value),
    ..metric.points
  ])
}

// --- JSON encoding ----------------------------------------------------------

/// JSON object for a single metric, matching Datadog's v1 series schema.
pub fn to_json(metric: Metric) -> json.Json {
  let base = [
    #("metric", json.string(metric.name)),
    #("type", json.string(type_to_string(metric.kind))),
    #("points", json.array(metric.points, of: point_to_json)),
    #("tags", json.array(metric.tags, of: json.string)),
  ]

  let with_host_field = case metric.host {
    option.Some(h) -> [#("host", json.string(h)), ..base]
    option.None -> base
  }

  case metric.interval {
    option.Some(i) -> [#("interval", json.int(i)), ..with_host_field]
    option.None -> with_host_field
  }
  |> json.object
}

fn point_to_json(point: Point) -> json.Json {
  json.preprocessed_array([json.int(point.timestamp), json.float(point.value)])
}

fn type_to_string(kind: MetricType) -> String {
  case kind {
    Gauge -> "gauge"
    Count -> "count"
    Rate -> "rate"
  }
}
