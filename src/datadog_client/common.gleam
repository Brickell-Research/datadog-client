@external(erlang, "erlang", "system_time")
fn erlang_system_time(unit: SystemTimeUnit) -> Int

/// Unit selector for the Erlang `system_time` BIF.
pub type SystemTimeUnit {
  Second
}

/// Current Unix time in seconds.
pub fn now_seconds() -> Int {
  erlang_system_time(Second)
}
