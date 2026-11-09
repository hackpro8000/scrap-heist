// Work shared between build machines. With --work-port this run asks the
// local agent (scripts/standby-agent.py) for its next job over a socket, one
// line each way, so a machine that finishes early simply takes more and no
// work waits on a busy machine.

use crate::cache;
use std::cell::RefCell;
use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;

type Job = Box<dyn FnOnce() -> Result<(), String>>;

thread_local! {
	// With --bake-only, the paints the script asked for, by chunk, to bake
	// once it has run: only then can a machine take them in any order.
	static DEFERRED: RefCell<HashMap<usize, Vec<Job>>> = RefCell::new(HashMap::new());
}

pub fn defer(chunk: usize, job: Job) {
	DEFERRED.with(|jobs| jobs.borrow_mut().entry(chunk).or_default().push(job));
}

struct Queue {
	stream: BufReader<TcpStream>,
}

impl Queue {
	fn connect(port: u16) -> std::io::Result<Queue> {
		Ok(Queue { stream: BufReader::new(TcpStream::connect(("127.0.0.1", port))?) })
	}

	// The next job of this kind, or None when every job is taken.
	fn next(&mut self, kind: &str, total: usize) -> Option<usize> {
		writeln!(self.stream.get_mut(), "{kind} {total}").ok()?;
		let mut answer = String::new();
		self.stream.read_line(&mut answer).ok()?;
		answer.trim().parse().ok()
	}
}

// Bakes chunks until none are left. Every machine's script run defers the
// same paints, so any machine can bake any chunk.
pub fn bake_claimed(port: u16) -> Result<(), String> {
	let mut queue = Queue::connect(port).map_err(|e| e.to_string())?;
	let mut jobs = DEFERRED.with(|jobs| std::mem::take(&mut *jobs.borrow_mut()));
	while let Some(chunk) = queue.next("bake", cache::BAKE_CHUNKS) {
		for job in jobs.remove(&chunk).into_iter().flatten() {
			job()?;
		}
	}
	Ok(())
}

// Claims renders one at a time. The queue hands them out in order, so a claim
// is always at or ahead of the render the loop has reached.
pub struct RenderClaims {
	queue: Queue,
	total: usize,
	held: Option<usize>,
	exhausted: bool,
}

impl RenderClaims {
	pub fn connect(port: u16, total: usize) -> Result<RenderClaims, String> {
		Ok(RenderClaims { queue: Queue::connect(port).map_err(|e| e.to_string())?, total, held: None, exhausted: false })
	}

	pub fn mine(&mut self, at: usize) -> bool {
		if self.held.is_none() && !self.exhausted {
			self.held = self.queue.next("render", self.total);
			self.exhausted = self.held.is_none();
		}
		if self.held == Some(at) {
			self.held = None;
			return true;
		}
		false
	}
}
