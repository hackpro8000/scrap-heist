// Progress lines on stderr while a model builds. Each line carries the time
// since the build started, and work inside a cached build indents under it.

use std::cell::Cell;
use std::sync::{Mutex, OnceLock};
use std::time::Instant;

static STARTED: OnceLock<Instant> = OnceLock::new();

thread_local! {
	static DEPTH: Cell<usize> = const { Cell::new(0) };
}

pub fn say(message: &str) {
	let elapsed = STARTED.get_or_init(Instant::now).elapsed().as_secs_f64();
	let indent = "  ".repeat(DEPTH.with(Cell::get));
	eprintln!("[{elapsed:7.1}s] {indent}{message}");
}

// A stage's total: said now, and kept for the end of the run, where main.rs
// prints the totals again on stdout. A build machine keeps only the end of a
// log, and the script's own output is shown after every line said here.
static TOTALS: Mutex<Vec<String>> = Mutex::new(Vec::new());

pub fn total(message: &str) {
	say(message);
	TOTALS.lock().expect("totals").push(message.to_string());
}

pub fn totals() -> Vec<String> {
	TOTALS.lock().expect("totals").clone()
}

// Runs `work` one level deeper, so the lines it prints indent under the caller's.
pub fn nested<T>(work: impl FnOnce() -> T) -> T {
	DEPTH.with(|depth| depth.set(depth.get() + 1));
	let result = work();
	DEPTH.with(|depth| depth.set(depth.get() - 1));
	result
}

// A cache key made readable: source hashes dropped, so "Barrels-1f2e…" reads
// "Barrels" and a slab's key reads as its label and placement.
pub fn label(key: &str) -> String {
	let hash = |s: &str| s.len() == 16 && s.chars().all(|c| c.is_ascii_hexdigit());
	key.split_whitespace()
		.filter_map(|token| {
			let Some((name, tail)) = token.rsplit_once('-') else {
				return Some(token);
			};
			if !hash(tail) {
				return Some(token);
			}
			if hash(name) { None } else { Some(name) }
		})
		.collect::<Vec<_>>()
		.join(" ")
}
