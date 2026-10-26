// uikit: runs a UI kit script (art/ui/<Kit>/ui.luau) that paints brushed
// UI textures, and writes each element as a PNG, a slices.luau listing each
// element's size and 9-slice centre, and a preview.png the script lays out.

mod canvas;

use canvas::{Brush, Canvas, Outline, Shape};
use mlua::{AnyUserData, Lua, Table, UserData, UserDataMethods};
use std::cell::RefCell;
use std::path::Path;
use std::rc::Rc;

// Roblox's largest texture side.
const MAX_SIDE: usize = 1024;

struct CanvasHandle(Rc<RefCell<Canvas>>);

impl UserData for CanvasHandle {
	fn add_methods<M: UserDataMethods<Self>>(methods: &mut M) {
		methods.add_method("fill", |_, this, (shape, color, alpha): (Table, Table, Option<f64>)| {
			this.0.borrow_mut().fill(&outline(&shape)?, rgb(&color)?, alpha.unwrap_or(1.0));
			Ok(())
		});
		methods.add_method("shadow", |_, this, (shape, dx, dy, blur, alpha): (Table, f64, f64, f64, Option<f64>)| {
			this.0.borrow_mut().shadow(&outline(&shape)?, dx, dy, blur, alpha.unwrap_or(0.6));
			Ok(())
		});
		methods.add_method("brushwork", |_, this, (shape, strength, scale, angle, brush): (Table, Option<f64>, Option<f64>, Option<f64>, Option<String>)| {
			let angle = angle.unwrap_or(0.0).to_radians();
			let name = brush.unwrap_or_else(|| "dab".to_string());
			let brush = Brush::named(&name).ok_or_else(|| mlua::Error::runtime(format!("unknown brush {name}; use dab, drag, dry, hatch or sponge")))?;
			this.0.borrow_mut().brushwork(&outline(&shape)?, strength.unwrap_or(1.0), scale.unwrap_or(1.0), angle, brush);
			Ok(())
		});
		methods.add_method("bevel", |_, this, (shape, width, light, dark, strength): (Table, f64, Table, Table, Option<f64>)| {
			this.0.borrow_mut().bevel(&outline(&shape)?, width, rgb(&light)?, rgb(&dark)?, strength.unwrap_or(1.0));
			Ok(())
		});
		methods.add_method("halftone", |_, this, (shape, color, spacing, angle, reach, tone): (Table, Table, Option<f64>, Option<f64>, Option<f64>, Option<f64>)| {
			let angle = angle.unwrap_or(45.0).to_radians();
			this.0.borrow_mut().halftone(&outline(&shape)?, rgb(&color)?, spacing.unwrap_or(5.0), angle, reach.unwrap_or(24.0), tone.unwrap_or(0.0));
			Ok(())
		});
		methods.add_method("highlight", |_, this, (shape, color, inset, width): (Table, Table, Option<f64>, Option<f64>)| {
			this.0.borrow_mut().highlight(&outline(&shape)?, rgb(&color)?, inset.unwrap_or(3.0), width.unwrap_or(1.5));
			Ok(())
		});
		methods.add_method("rim", |_, this, (shape, width, color): (Table, f64, Table)| {
			this.0.borrow_mut().rim(&outline(&shape)?, width, rgb(&color)?);
			Ok(())
		});
		methods.add_method("rust", |_, this, (shape, amount, reach, seed): (Table, f64, Option<f64>, Option<f64>)| {
			this.0.borrow_mut().rust(&outline(&shape)?, amount, reach.unwrap_or(14.0), seed.unwrap_or(0.0));
			Ok(())
		});
		methods.add_method("stripes", |_, this, (shape, a, b, width, angle): (Table, Table, Table, f64, Option<f64>)| {
			let angle = angle.unwrap_or(45.0).to_radians();
			this.0.borrow_mut().stripes(&outline(&shape)?, rgb(&a)?, rgb(&b)?, width, angle);
			Ok(())
		});
		methods.add_method("grime", |_, this, (shape, amount): (Table, f64)| {
			this.0.borrow_mut().grime(&outline(&shape)?, amount);
			Ok(())
		});
		methods.add_method("draw", |_, this, (source, x, y, w, h): (AnyUserData, f64, f64, Option<f64>, Option<f64>)| {
			let source = source.borrow::<CanvasHandle>()?.0.clone();
			let source = source.borrow();
			let (w, h) = (w.unwrap_or(source.width as f64), h.unwrap_or(source.height as f64));
			this.0.borrow_mut().draw(&source, x, y, w, h);
			Ok(())
		});
		methods.add_method("drawSliced", |_, this, (source, slice, x, y, w, h): (AnyUserData, Table, f64, f64, f64, f64)| {
			let source = source.borrow::<CanvasHandle>()?.0.clone();
			let slice = [slice.get(1)?, slice.get(2)?, slice.get(3)?, slice.get(4)?];
			this.0.borrow_mut().draw_sliced(&source.borrow(), slice, x, y, w, h);
			Ok(())
		});
		methods.add_method("size", |_, this, ()| {
			let canvas = this.0.borrow();
			Ok((canvas.width, canvas.height))
		});
	}
}

fn rgb(color: &Table) -> mlua::Result<[f32; 3]> {
	Ok([color.get(1)?, color.get(2)?, color.get(3)?])
}

// A shape table: {rect = {x0, y0, x1, y1}, radius =}, {circle = {x, y, r}}
// or {polygon = {x1, y1, x2, y2, ...}}, with optional wobble and seed.
fn outline(table: &Table) -> mlua::Result<Outline> {
	let shape = if let Some(rect) = table.get::<Option<Table>>("rect")? {
		Shape::Rect { x0: rect.get(1)?, y0: rect.get(2)?, x1: rect.get(3)?, y1: rect.get(4)?, radius: table.get::<Option<f64>>("radius")?.unwrap_or(0.0) }
	} else if let Some(circle) = table.get::<Option<Table>>("circle")? {
		Shape::Circle { x: circle.get(1)?, y: circle.get(2)?, radius: circle.get(3)? }
	} else if let Some(polygon) = table.get::<Option<Table>>("polygon")? {
		let numbers: Vec<f64> = polygon.sequence_values().collect::<mlua::Result<_>>()?;
		Shape::Polygon(numbers.chunks_exact(2).map(|p| (p[0], p[1])).collect())
	} else {
		return Err(mlua::Error::runtime("shape needs rect, circle or polygon"));
	};
	Ok(Outline { shape, wobble: table.get::<Option<f64>>("wobble")?.unwrap_or(0.0), seed: table.get::<Option<f64>>("seed")?.unwrap_or(0.0) })
}

struct Element {
	name: String,
	canvas: Rc<RefCell<Canvas>>,
	slice: Option<[f64; 4]>,
}

fn run(dir: &Path) -> Result<(), String> {
	let script = dir.join("ui.luau");
	let source = std::fs::read_to_string(&script).map_err(|e| format!("{}: {e}", script.display()))?;
	let lua = Lua::new();
	let elements: Rc<RefCell<Vec<Element>>> = Rc::new(RefCell::new(Vec::new()));
	let preview: Rc<RefCell<Option<Rc<RefCell<Canvas>>>>> = Rc::new(RefCell::new(None));
	let install = || -> mlua::Result<()> {
		let globals = lua.globals();
		let canvas_api = lua.create_table()?;
		canvas_api.set(
			"new",
			lua.create_function(|_, (w, h, r, g, b, a): (usize, usize, Option<f32>, Option<f32>, Option<f32>, Option<f32>)| {
				if w == 0 || h == 0 || w > MAX_SIDE || h > MAX_SIDE {
					return Err(mlua::Error::runtime(format!("canvas {w}x{h} must be 1 to {MAX_SIDE} pixels a side")));
				}
				let color = [r.unwrap_or(0.0), g.unwrap_or(0.0), b.unwrap_or(0.0), a.unwrap_or(0.0)];
				Ok(CanvasHandle(Rc::new(RefCell::new(Canvas::new(w, h, color)))))
			})?,
		)?;
		globals.set("Canvas", canvas_api)?;
		let ui = lua.create_table()?;
		let added = elements.clone();
		ui.set(
			"element",
			lua.create_function(move |_, (name, canvas, options): (String, AnyUserData, Option<Table>)| {
				let slice = match options.map(|o| o.get::<Option<Table>>("slice")).transpose()?.flatten() {
					Some(s) => Some([s.get(1)?, s.get(2)?, s.get(3)?, s.get(4)?]),
					None => None,
				};
				added.borrow_mut().push(Element { name, canvas: canvas.borrow::<CanvasHandle>()?.0.clone(), slice });
				Ok(())
			})?,
		)?;
		let shown = preview.clone();
		ui.set(
			"preview",
			lua.create_function(move |_, canvas: AnyUserData| {
				*shown.borrow_mut() = Some(canvas.borrow::<CanvasHandle>()?.0.clone());
				Ok(())
			})?,
		)?;
		globals.set("ui", ui)?;
		Ok(())
	};
	install().map_err(|e| e.to_string())?;
	lua.load(source).set_name(format!("@{}", script.display())).exec().map_err(|e| e.to_string())?;

	let elements = elements.borrow();
	if elements.is_empty() {
		return Err("ui.luau added no elements (call ui.element)".into());
	}
	let mut slices = String::from("-- Generated by uikit from ui.luau; do not edit.\n-- Each element's pixel size and, for 9-sliced ones, its SliceCenter.\nreturn {\n");
	for element in elements.iter() {
		let canvas = element.canvas.borrow();
		std::fs::write(dir.join(format!("{}.png", element.name)), canvas.encode_png()).map_err(|e| e.to_string())?;
		let center = match element.slice {
			Some([l, t, r, b]) => format!(", slice = Rect.new({l}, {t}, {}, {})", canvas.width as f64 - r, canvas.height as f64 - b),
			None => String::new(),
		};
		slices += &format!("\t{} = {{ size = Vector2.new({}, {}){center} }},\n", element.name, canvas.width, canvas.height);
	}
	slices += "}\n";
	std::fs::write(dir.join("slices.luau"), slices).map_err(|e| e.to_string())?;
	if let Some(preview) = preview.borrow().as_ref() {
		std::fs::write(dir.join("preview.png"), preview.borrow().encode_png()).map_err(|e| e.to_string())?;
	}
	eprintln!("{}: {} elements", dir.display(), elements.len());
	Ok(())
}

fn main() {
	let Some(dir) = std::env::args().nth(1) else {
		eprintln!("usage: uikit <kit folder>");
		std::process::exit(2);
	};
	if let Err(error) = run(Path::new(&dir)) {
		eprintln!("{error}");
		std::process::exit(1);
	}
}
