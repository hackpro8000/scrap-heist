// Work shared between build machines. With --work-port this run asks the
// local agent (scripts/standby-agent.py) for its next job over a socket, one
// line each way, so a machine that finishes early simply takes more and no
// work waits on a busy machine.

use crate::{cache, progress};
use std::cell::RefCell;
use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;
use std::time::Instant;

type Job = Box<dyn FnOnce() -> Result<(), String>>;

thread_local! {
	// With --share-bakes, the paints the script asked for, by chunk, to bake
	// once it has run: only then can a machine take them in any order.
	static DEFERRED: RefCell<HashMap<usize, Vec<Job>>> = RefCell::new(HashMap::new());
	// Whole-part saves, which must wait for those paints.
	static SAVES: RefCell<Vec<Job>> = const { RefCell::new(Vec::new()) };
}

pub fn defer(chunk: usize, job: Job) {
	DEFERRED.with(|jobs| jobs.borrow_mut().entry(chunk).or_default().push(job));
}

pub fn defer_save(job: Job) {
	SAVES.with(|saves| saves.borrow_mut().push(job));
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

// Bakes chunks until none are left, waits while the agent swaps baked layers
// with the other machines, then paints everything still held back: the layers
// this machine didn't bake now load from the cache, and any that never arrived
// are baked here. Every machine's script defers the same paints, so any machine
// can bake any chunk.
pub fn bake_and_swap(port: u16) -> Result<(), String> {
	let mut queue = Queue::connect(port).map_err(|e| e.to_string())?;
	let mut jobs = DEFERRED.with(|jobs| std::mem::take(&mut *jobs.borrow_mut()));
	// Each stage's total is kept (progress::total), so one machine's log shows
	// where a shared build's time went: a paint whose layers all load still
	// costs its keys, its part's chunks merged and its shade pass set up.
	let (stage, before) = (Instant::now(), cache::tally());
	let (mut claimed, mut painted) = (0, 0);
	while let Some(chunk) = queue.next("bake", cache::BAKE_CHUNKS) {
		claimed += 1;
		for job in jobs.remove(&chunk).into_iter().flatten() {
			painted += 1;
			job()?;
		}
	}
	progress::say("baked every chunk this machine claimed");
	progress::total(&format!("TIMING claimed bakes: {painted} paints in {claimed} of {} chunks, {:.1}s with the waits to claim; {}", cache::BAKE_CHUNKS, stage.elapsed().as_secs_f64(), cache::tally_since(before)));
	let stage = Instant::now();
	queue.next("swap", 1);
	progress::total(&format!("TIMING swap: {:.1}s pushing, waiting for the other machines and fetching", stage.elapsed().as_secs_f64()));
	let (stage, before) = (Instant::now(), cache::tally());
	let mut chunks: Vec<_> = jobs.into_iter().collect();
	chunks.sort_by_key(|(chunk, _)| *chunk);
	let mut painted = 0;
	for job in chunks.into_iter().flat_map(|(_, jobs)| jobs) {
		painted += 1;
		job()?;
	}
	progress::total(&format!("TIMING paints after the swap: {painted} paints, {:.1}s; {} (baked here means a layer that did not arrive)", stage.elapsed().as_secs_f64(), cache::tally_since(before)));
	let stage = Instant::now();
	let saves = SAVES.with(|saves| std::mem::take(&mut *saves.borrow_mut()));
	let saved = saves.len();
	for save in saves {
		save()?;
	}
	progress::total(&format!("TIMING whole-part saves: {saved} in {:.1}s", stage.elapsed().as_secs_f64()));
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
