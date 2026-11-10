-- A blank test block for judging the brush strokes: one flat colour, no wear.
-- Its top shows how strokes lie on flat tops, its sides how they lie on walls.
useTexelDensity(40)

part("Canvas", nil, { 0.42, 0.45, 0.5 }, function(mesh)
	box(mesh, 0, 0, 0, 8, 8, 8)
end, nil, 0)

finishParts()
