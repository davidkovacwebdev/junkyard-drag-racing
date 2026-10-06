//! The geometry behind `RoadNetwork` (scripts/world/road.gd): decimating,
//! filleting, kerb offsets, lane markings and the drawing chunks. road.gd keeps
//! the node, caching and drawing; the point loops live here.
//!
//! Vector maths copies Godot's single-precision `Vector2` operation for
//! operation (see `godot_vec`), so a road builds the same here as it did in
//! GDScript.

use godot::prelude::*;
use std::collections::HashMap;

use crate::dsp::variant_f64;

/// Godot's own `Vector2` methods where gdext's differ in rounding or approach.
mod godot_vec {
    use godot::prelude::Vector2;

    pub fn length_squared(v: Vector2) -> f32 {
        v.x * v.x + v.y * v.y
    }

    pub fn normalized(v: Vector2) -> Vector2 {
        let l = v.x * v.x + v.y * v.y;
        if l == 0.0 {
            return v;
        }
        let l = l.sqrt();
        Vector2::new(v.x / l, v.y / l)
    }

    pub fn orthogonal(v: Vector2) -> Vector2 {
        Vector2::new(v.y, -v.x)
    }

    pub fn dot(a: Vector2, b: Vector2) -> f32 {
        a.x * b.x + a.y * b.y
    }

    pub fn cross(a: Vector2, b: Vector2) -> f32 {
        a.x * b.y - a.y * b.x
    }

    pub fn angle_to(a: Vector2, b: Vector2) -> f32 {
        cross(a, b).atan2(dot(a, b))
    }

    pub fn distance_squared_to(a: Vector2, b: Vector2) -> f32 {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
    }

    pub fn distance_to(a: Vector2, b: Vector2) -> f32 {
        distance_squared_to(a, b).sqrt()
    }

    pub fn lerp(a: Vector2, b: Vector2, weight: f64) -> Vector2 {
        let w = weight as f32;
        Vector2::new(a.x + (b.x - a.x) * w, a.y + (b.y - a.y) * w)
    }

    pub fn scaled(v: Vector2, scale: f64) -> Vector2 {
        let s = scale as f32;
        Vector2::new(v.x * s, v.y * s)
    }

    /// `Vector2i((v / divisor).floor())`.
    pub fn cell(v: Vector2, divisor: f64) -> (i32, i32) {
        let d = divisor as f32;
        ((v.x / d).floor() as i32, (v.y / d).floor() as i32)
    }

    /// `Geometry2D.segment_intersects_segment()`.
    pub fn segment_intersection(from_a: Vector2, to_a: Vector2, from_b: Vector2, to_b: Vector2) -> Option<Vector2> {
        const CMP_EPSILON: f32 = 0.00001;
        let b = to_a - from_a;
        let c = from_b - from_a;
        let d = to_b - from_a;
        let ab_length = dot(b, b);
        if ab_length <= 0.0 {
            return None;
        }
        let bn = Vector2::new(b.x / ab_length, b.y / ab_length);
        let c = Vector2::new(c.x * bn.x + c.y * bn.y, c.y * bn.x - c.x * bn.y);
        let d = Vector2::new(d.x * bn.x + d.y * bn.y, d.y * bn.x - d.x * bn.y);
        if (c.y < -CMP_EPSILON && d.y < -CMP_EPSILON) || (c.y > CMP_EPSILON && d.y > CMP_EPSILON) {
            return None;
        }
        if is_equal_approx(c.y, d.y) {
            return None;
        }
        let ab_position = d.x + (c.x - d.x) * d.y / (d.y - c.y);
        if !(0.0..=1.0).contains(&ab_position) {
            return None;
        }
        Some(from_a + b * ab_position)
    }

    fn is_equal_approx(a: f32, b: f32) -> bool {
        if a == b {
            return true;
        }
        let tolerance = (0.00001 * a.abs()).max(0.00001);
        (a - b).abs() < tolerance
    }
}

use godot_vec::*;

/// Godot's `Rect2` as GDScript used it here: grown plots and segment bounds.
#[derive(Clone, Copy)]
struct Bounds {
    position: Vector2,
    size: Vector2,
}

impl Bounds {
    /// `Rect2(a, Vector2.ZERO).expand(b)`.
    fn of_segment(a: Vector2, b: Vector2) -> Self {
        let begin = Vector2::new(a.x.min(b.x), a.y.min(b.y));
        let end = Vector2::new(a.x.max(b.x), a.y.max(b.y));
        Bounds { position: begin, size: end - begin }
    }

    fn from_rect(rect: Rect2) -> Self {
        Bounds { position: rect.position, size: rect.size }
    }

    fn grow(self, amount: f64) -> Self {
        let amount = amount as f32;
        Bounds {
            position: Vector2::new(self.position.x - amount, self.position.y - amount),
            size: Vector2::new(self.size.x + amount * 2.0, self.size.y + amount * 2.0),
        }
    }

    fn end(self) -> Vector2 {
        self.position + self.size
    }

    fn has_point(self, point: Vector2) -> bool {
        point.x >= self.position.x
            && point.y >= self.position.y
            && point.x < self.position.x + self.size.x
            && point.y < self.position.y + self.size.y
    }
}

fn distance_squared_to_segment(point: Vector2, a: Vector2, b: Vector2) -> f64 {
    let ab = b - a;
    let length_squared = length_squared(ab) as f64;
    if length_squared <= 0.0 {
        return distance_squared_to(point, a) as f64;
    }
    let t = (dot(point - a, ab) as f64 / length_squared).clamp(0.0, 1.0);
    distance_squared_to(point, a + scaled(ab, t)) as f64
}

fn polylines(array: &Array<PackedVector2Array>) -> Vec<Vec<Vector2>> {
    array.iter_shared().map(|points| points.to_vec()).collect()
}

fn to_array(lines: &[Vec<Vector2>]) -> Array<PackedVector2Array> {
    lines.iter().map(|line| PackedVector2Array::from(line.as_slice())).collect()
}

// --- Segment grid -------------------------------------------------------------

/// Uniform-grid broad phase over a set of polylines. Each segment is listed in
/// every cell its bounding box covers once grown by `grow`, so a cell's list is
/// a superset of the segments that could reach a point inside it.
#[derive(GodotClass)]
#[class(init, base = RefCounted)]
pub struct SegmentGrid {
    cell_size: f64,
    cells: HashMap<(i32, i32), Vec<u32>>,
    segment_road: Vec<u32>,
    segment_from: Vec<Vector2>,
    segment_to: Vec<Vector2>,
}

#[godot_api]
impl SegmentGrid {
    #[func]
    fn create(roads: Array<PackedVector2Array>, cell_size: f64, grow: f64) -> Gd<Self> {
        Gd::from_object(Self::build(&polylines(&roads), cell_size, grow))
    }

    /// True if any segment lies within `threshold` of `point`. Walks every cell
    /// the square of `threshold` around the point touches.
    #[func]
    fn is_near(&self, point: Vector2, threshold: f64) -> bool {
        let limit = threshold * threshold;
        let reach = Vector2::new(threshold as f32, threshold as f32);
        let first = cell(point - reach, self.cell_size);
        let last = cell(point + reach, self.cell_size);
        for cx in first.0..=last.0 {
            for cy in first.1..=last.1 {
                let Some(candidates) = self.cells.get(&(cx, cy)) else { continue };
                for &segment in candidates {
                    let s = segment as usize;
                    if distance_squared_to_segment(point, self.segment_from[s], self.segment_to[s]) < limit {
                        return true;
                    }
                }
            }
        }
        false
    }
}

impl SegmentGrid {
    fn build(roads: &[Vec<Vector2>], cell_size: f64, grow: f64) -> Self {
        let mut grid = SegmentGrid {
            cell_size,
            cells: HashMap::new(),
            segment_road: Vec::new(),
            segment_from: Vec::new(),
            segment_to: Vec::new(),
        };
        for (road_index, points) in roads.iter().enumerate() {
            for pair in points.windows(2) {
                let segment = grid.segment_from.len() as u32;
                grid.segment_road.push(road_index as u32);
                grid.segment_from.push(pair[0]);
                grid.segment_to.push(pair[1]);
                let mut bounds = Bounds::of_segment(pair[0], pair[1]);
                if grow != 0.0 {
                    bounds = bounds.grow(grow);
                }
                let first = cell(bounds.position, cell_size);
                let last = cell(bounds.end(), cell_size);
                for cx in first.0..=last.0 {
                    for cy in first.1..=last.1 {
                        grid.cells.entry((cx, cy)).or_default().push(segment);
                    }
                }
            }
        }
        grid
    }

    /// True if a segment of a road other than `own_road` lies within `threshold`
    /// of `point`. Only looks in the point's own cell, so the grid must have
    /// been grown by at least `threshold`.
    fn is_blocked(&self, point: Vector2, threshold: f64, own_road: usize) -> bool {
        let Some(candidates) = self.cells.get(&cell(point, self.cell_size)) else { return false };
        let limit = threshold * threshold;
        candidates.iter().any(|&segment| {
            let s = segment as usize;
            self.segment_road[s] as usize != own_road
                && distance_squared_to_segment(point, self.segment_from[s], self.segment_to[s]) < limit
        })
    }
}

// --- Polyline shaping -----------------------------------------------------------

#[derive(GodotClass)]
#[class(no_init)]
pub struct RoadGeometry;

#[godot_api]
impl RoadGeometry {
    /// Douglas-Peucker: drop points that stay within `tolerance` of the line
    /// between the points that survive.
    #[func]
    fn simplify(points: PackedVector2Array, tolerance: f64) -> PackedVector2Array {
        let points = points.as_slice();
        let n = points.len();
        if n < 3 || tolerance <= 0.0 {
            return PackedVector2Array::from(points);
        }
        let mut keep = vec![false; n];
        keep[0] = true;
        keep[n - 1] = true;
        let tolerance_squared = tolerance * tolerance;
        let mut spans = vec![(0usize, n - 1)];
        while let Some((first, last)) = spans.pop() {
            if last - first < 2 {
                continue;
            }
            let a = points[first];
            let ab = points[last] - a;
            let length_squared = length_squared(ab) as f64;
            let mut worst = -1.0f64;
            let mut worst_index = 0;
            for (i, &point) in points.iter().enumerate().take(last).skip(first + 1) {
                let deviation = if length_squared <= 0.0 {
                    distance_squared_to(point, a) as f64
                } else {
                    let t = (dot(point - a, ab) as f64 / length_squared).clamp(0.0, 1.0);
                    distance_squared_to(point, a + scaled(ab, t)) as f64
                };
                if deviation > worst {
                    worst = deviation;
                    worst_index = i;
                }
            }
            if worst > tolerance_squared {
                keep[worst_index] = true;
                spans.push((first, worst_index));
                spans.push((worst_index, last));
            }
        }
        let kept: Vec<Vector2> = points.iter().zip(&keep).filter(|(_, keep)| **keep).map(|(point, _)| *point).collect();
        PackedVector2Array::from(kept)
    }

    /// Replace every turn sharper than `threshold` radians with a short arc of
    /// `radius`, never eating more than half of either neighbouring segment.
    #[func]
    fn round_sharp_corners(points: PackedVector2Array, radius: f64, threshold: f64) -> PackedVector2Array {
        let points = points.as_slice();
        if points.len() < 3 || radius <= 0.0 {
            return PackedVector2Array::from(points);
        }
        let mut out = vec![points[0]];
        for window in points.windows(3) {
            let (prev, curr, next) = (window[0], window[1], window[2]);
            let mut in_dir = curr - prev;
            let mut out_dir = next - curr;
            if (length_squared(in_dir) as f64) < 0.0001 || (length_squared(out_dir) as f64) < 0.0001 {
                out.push(curr);
                continue;
            }
            in_dir = normalized(in_dir);
            out_dir = normalized(out_dir);
            if (angle_to(in_dir, out_dir).abs() as f64) < threshold {
                out.push(curr);
                continue;
            }
            let r = radius.min((distance_to(prev, curr) as f64).min(distance_to(curr, next) as f64) * 0.5);
            let p1 = curr - scaled(in_dir, r);
            let p2 = curr + scaled(out_dir, r);
            const ARC_STEPS: i32 = 6;
            for step in 0..=ARC_STEPS {
                let t = step as f64 / ARC_STEPS as f64;
                out.push(lerp(lerp(p1, curr, t), lerp(curr, p2, t), t));
            }
        }
        out.push(points[points.len() - 1]);
        PackedVector2Array::from(out)
    }

    /// Push points out of any keep-clear plot (grown by `margin`), along
    /// whichever axis the road mostly runs.
    #[func]
    fn avoid_clear_areas(points: PackedVector2Array, areas: Array<Rect2>, margin: f64) -> PackedVector2Array {
        let points = points.as_slice();
        if areas.is_empty() || points.len() < 2 {
            return PackedVector2Array::from(points);
        }
        let grown: Vec<Bounds> = areas.iter_shared().map(|area| Bounds::from_rect(area).grow(margin)).collect();
        let last = points.len() - 1;
        let out: Vec<Vector2> = (0..points.len())
            .map(|i| {
                let direction = match i {
                    0 => points[1] - points[0],
                    _ if i == last => points[i] - points[i - 1],
                    _ => points[i + 1] - points[i - 1],
                };
                let mut point = points[i];
                for area in &grown {
                    if !area.has_point(point) {
                        continue;
                    }
                    let end = area.end();
                    if direction.x.abs() >= direction.y.abs() {
                        point.y = if (point.y as f64 - area.position.y as f64).abs() < (point.y as f64 - end.y as f64).abs() {
                            area.position.y
                        } else {
                            end.y
                        };
                    } else {
                        point.x = if (point.x as f64 - area.position.x as f64).abs() < (point.x as f64 - end.x as f64).abs() {
                            area.position.x
                        } else {
                            end.x
                        };
                    }
                }
                point
            })
            .collect();
        PackedVector2Array::from(out)
    }

    /// Lane markings for every drawing road: the points that need a disc under
    /// the ribbon, the solid edge lines and the centre dashes, all broken
    /// wherever another road (per `blocking`) runs into them. `settings` holds
    /// road_width, edge_inset, dash_length, dash_gap and block_distance.
    #[func]
    fn build_markings(draw_roads: Array<PackedVector2Array>, blocking: Gd<SegmentGrid>, settings: VarDictionary) -> VarDictionary {
        let setting = |key: &str| settings.get(key).map_or(0.0, |v| variant_f64(&v));
        let markings = Markings {
            road_width: setting("road_width"),
            edge_inset: setting("edge_inset"),
            dash_length: setting("dash_length"),
            dash_gap: setting("dash_gap"),
            block_distance: setting("block_distance"),
            blocking: &blocking.bind(),
        };
        let roads = polylines(&draw_roads);
        let mut corner_points = Vec::new();
        let mut edge_runs = Vec::new();
        let mut dash_runs = Vec::new();
        for (index, points) in roads.iter().enumerate() {
            corner_points.push(corners_of(points));
            markings.collect_edge_runs(points, index, &mut edge_runs);
            markings.collect_dash_runs(points, index, &mut dash_runs);
        }
        vdict! {
            "corner_points" => &to_array(&corner_points),
            "edge_runs" => &to_array(&edge_runs),
            "dash_runs" => &to_array(&dash_runs),
        }
    }

    /// Sort the finished drawing geometry into square chunks of `chunk_size`.
    /// Returns chunk cell -> {ribbons, discs, islands, points, colors, indices},
    /// the last three being the chunk's markings as one triangle list.
    #[func]
    fn build_draw_chunks(
        draw_roads: Array<PackedVector2Array>,
        markings: VarDictionary,
        roundabouts: Array<Vector2>,
        style: VarDictionary,
    ) -> VarDictionary {
        let field = |key: &str| style.get(key).map_or(0.0, |v| variant_f64(&v));
        let color = |key: &str| style.get(key).map_or(Color::WHITE, |v| v.to::<Color>());
        let marking_lines = |key: &str| polylines(&markings.get(key).map_or_else(Array::new, |v| v.to::<Array<PackedVector2Array>>()));
        let mut chunks = Chunks::new(field("chunk_size"));

        let corner_points = marking_lines("corner_points");
        for (i, points) in polylines(&draw_roads).iter().enumerate() {
            if points.len() < 2 {
                continue;
            }
            chunks.add_ribbon_pieces(points);
            chunks.at(points[0]).discs.push(points[0]);
            chunks.at(points[points.len() - 1]).discs.push(points[points.len() - 1]);
            for &corner in &corner_points[i] {
                chunks.at(corner).discs.push(corner);
            }
        }
        for center in roundabouts.iter_shared() {
            chunks.at(center).islands.push(center);
        }
        for run in marking_lines("edge_runs") {
            for pair in run.windows(2) {
                chunks.at(scaled(pair[0] + pair[1], 0.5)).edge_segments.extend_from_slice(pair);
            }
        }
        for run in marking_lines("dash_runs") {
            for pair in run.windows(2) {
                chunks.at(scaled(pair[0] + pair[1], 0.5)).dash_segments.extend_from_slice(pair);
            }
        }

        let (edge_color, edge_width) = (color("edge_color"), field("edge_width"));
        let (line_color, line_width) = (color("line_color"), field("line_width"));
        let mut out = VarDictionary::new();
        for (cell, mut chunk) in chunks.into_ordered() {
            let mut batch = TriangleBatch::default();
            batch.add_segments(&chunk.edge_segments, edge_color, edge_width);
            batch.add_segments(&chunk.dash_segments, line_color, line_width);
            chunk.edge_segments.clear();
            chunk.dash_segments.clear();
            out.set(
                Vector2i::new(cell.0, cell.1),
                &vdict! {
                    "ribbons" => &to_array(&chunk.ribbons),
                    "discs" => &PackedVector2Array::from(chunk.discs.as_slice()),
                    "islands" => &PackedVector2Array::from(chunk.islands.as_slice()),
                    "points" => &PackedVector2Array::from(batch.points.as_slice()),
                    "colors" => &PackedColorArray::from(batch.colors.as_slice()),
                    "indices" => &PackedInt32Array::from(batch.indices.as_slice()),
                },
            );
        }
        out
    }
}

// --- Markings -----------------------------------------------------------------

/// The points along a road that need a disc under them. ~3°: anything
/// straighter than this is effectively collinear at road scale.
fn corners_of(points: &[Vector2]) -> Vec<Vector2> {
    const MIN_TURN: f64 = 0.05;
    points
        .windows(3)
        .filter_map(|w| {
            let a = w[1] - w[0];
            let b = w[2] - w[1];
            if (length_squared(a) as f64) < 0.0001 || (length_squared(b) as f64) < 0.0001 {
                return None;
            }
            ((angle_to(a, b).abs() as f64) > MIN_TURN).then_some(w[1])
        })
        .collect()
}

struct Markings<'a> {
    road_width: f64,
    edge_inset: f64,
    dash_length: f64,
    dash_gap: f64,
    /// How close a marking may get to another road before it breaks.
    block_distance: f64,
    blocking: &'a SegmentGrid,
}

impl Markings<'_> {
    fn blocked(&self, point: Vector2, index: usize) -> bool {
        self.blocking.is_blocked(point, self.block_distance, index)
    }

    /// Solid edge lines down both sides, broken wherever another road crosses.
    fn collect_edge_runs(&self, points: &[Vector2], index: usize, out_runs: &mut Vec<Vec<Vector2>>) {
        let inset = self.road_width * 0.5 - self.edge_inset;
        if inset <= 0.0 {
            return;
        }
        for side in [-inset, inset] {
            let dense = densify(&offset_polyline(points, side), (self.road_width * 0.3).max(24.0));
            let mut run = Vec::new();
            for point in dense {
                if self.blocked(point, index) {
                    append_run(out_runs, std::mem::take(&mut run));
                } else {
                    run.push(point);
                }
            }
            append_run(out_runs, run);
        }
    }

    /// Dashed centre line, one run per dash, with each dash edge placed at its
    /// exact arc-length position so decimation never shortens a dash.
    fn collect_dash_runs(&self, points: &[Vector2], index: usize, out_runs: &mut Vec<Vec<Vector2>>) {
        let dense = densify(points, 14.0);
        if dense.len() < 2 {
            return;
        }
        let period = (self.dash_length + self.dash_gap).max(1.0);
        let total = dense.windows(2).fold(0.0f64, |sum, w| sum + distance_to(w[1], w[0]) as f64);
        let edges = self.dash_edges(total, period);

        let mut run = Vec::new();
        let mut on_dash = self.dash_gap % period < self.dash_length;
        if on_dash {
            run.push(dense[0]);
        }
        let mut edge_index = 0;
        let mut travelled = 0.0f64;
        for w in dense.windows(2) {
            let (a, b) = (w[0], w[1]);
            let segment_length = distance_to(a, b) as f64;
            let segment_end = travelled + segment_length;
            while edge_index < edges.len() && edges[edge_index] as f64 <= segment_end + 0.0001 {
                let t = if segment_length <= 0.0 { 0.0 } else { (edges[edge_index] as f64 - travelled) / segment_length };
                let at = lerp(a, b, t.clamp(0.0, 1.0));
                if on_dash {
                    if !self.blocked(at, index) {
                        run.push(at);
                    }
                    append_run(out_runs, std::mem::take(&mut run));
                } else if !self.blocked(at, index) {
                    run.push(at);
                }
                on_dash = !on_dash;
                edge_index += 1;
            }
            if on_dash {
                if self.blocked(b, index) {
                    append_run(out_runs, std::mem::take(&mut run));
                } else {
                    run.push(b);
                }
            }
            travelled = segment_end;
        }
        append_run(out_runs, run);
    }

    /// Arc-length positions where the centre line flips between dash and gap.
    /// The marking turns on at `k*period - dash_gap` and off `dash_length` later.
    fn dash_edges(&self, total: f64, period: f64) -> Vec<f32> {
        let mut edges = Vec::new();
        let mut k = 0;
        loop {
            let off_edge = k as f64 * period + self.dash_length - self.dash_gap;
            if off_edge > total + period {
                break;
            }
            let on_edge = k as f64 * period - self.dash_gap;
            if on_edge >= 0.0 && on_edge <= total {
                edges.push(on_edge as f32);
            }
            if off_edge >= 0.0 && off_edge <= total {
                edges.push(off_edge as f32);
            }
            k += 1;
        }
        edges.sort_by(f32::total_cmp);
        edges
    }
}

/// One point is not a line: only keep runs worth drawing.
fn append_run(out_runs: &mut Vec<Vec<Vector2>>, run: Vec<Vector2>) {
    if run.len() >= 2 {
        out_runs.push(run);
    }
}

/// Subdivide long segments, so marks are laid out at a sane resolution.
fn densify(points: &[Vector2], max_length: f64) -> Vec<Vector2> {
    if points.len() < 2 || max_length <= 0.0 {
        return points.to_vec();
    }
    let mut out = vec![points[0]];
    for w in points.windows(2) {
        let steps = ((distance_to(w[0], w[1]) as f64 / max_length).ceil() as i64).max(1);
        for step in 1..=steps {
            out.push(lerp(w[0], w[1], step as f64 / steps as f64));
        }
    }
    out
}

/// Parallel offset with mitred joins, bevelled where a miter would fold.
fn offset_polyline(points: &[Vector2], distance: f64) -> Vec<Vector2> {
    let n = points.len();
    if n < 2 {
        return Vec::new();
    }
    const MITER_LIMIT: f64 = 2.0;
    let out: Vec<Vector2> = (0..n)
        .map(|i| {
            let offset_dir = if i == 0 {
                orthogonal(normalized(points[1] - points[0]))
            } else if i == n - 1 {
                orthogonal(normalized(points[i] - points[i - 1]))
            } else {
                let n_in = orthogonal(normalized(points[i] - points[i - 1]));
                let n_out = orthogonal(normalized(points[i + 1] - points[i]));
                let bisector = n_in + n_out;
                if (length_squared(bisector) as f64) < 0.0001 {
                    n_in
                } else {
                    let bisector = normalized(bisector);
                    let cos_half = dot(bisector, n_in) as f64;
                    if cos_half < 1.0 / MITER_LIMIT {
                        scaled(bisector, cos_half)
                    } else {
                        let c = cos_half as f32;
                        Vector2::new(bisector.x / c, bisector.y / c)
                    }
                }
            };
            points[i] + scaled(offset_dir, distance)
        })
        .collect();
    trim_offset_loops(out)
}

/// Around a corner tighter than the offset, the inner offset crosses back over
/// itself. Whenever the newest segment crosses a recent one, cut the loop out
/// at the crossing, leaving a clean cusp.
fn trim_offset_loops(points: Vec<Vector2>) -> Vec<Vector2> {
    if points.len() < 4 {
        return points;
    }
    const LOOP_WINDOW: usize = 64;
    let mut out = vec![points[0]];
    for &point in &points[1..] {
        if distance_squared_to(point, out[out.len() - 1]) as f64 > 0.01 {
            out.push(point);
        }
        let mut guard = 0;
        while out.len() >= 4 && guard < LOOP_WINDOW {
            guard += 1;
            let last = out.len() - 1;
            let first = last.saturating_sub(LOOP_WINDOW);
            let hit = (first..last - 2).find_map(|j| {
                segment_intersection(out[j], out[j + 1], out[last - 1], out[last]).map(|hit| (j, hit))
            });
            let Some((j, hit)) = hit else { break };
            out.truncate(j + 1);
            out.push(hit);
        }
    }
    out
}

// --- Draw chunks --------------------------------------------------------------

#[derive(Default)]
struct DrawChunk {
    ribbons: Vec<Vec<Vector2>>,
    discs: Vec<Vector2>,
    islands: Vec<Vector2>,
    /// Pairs of points, one marking line per pair.
    edge_segments: Vec<Vector2>,
    dash_segments: Vec<Vector2>,
}

/// Chunks by cell, remembering the order they were first touched in.
struct Chunks {
    size: f64,
    order: Vec<(i32, i32)>,
    by_cell: HashMap<(i32, i32), DrawChunk>,
}

impl Chunks {
    fn new(size: f64) -> Self {
        Chunks { size, order: Vec::new(), by_cell: HashMap::new() }
    }

    fn cell_of(&self, point: Vector2) -> (i32, i32) {
        cell(point, self.size)
    }

    fn for_cell(&mut self, cell: (i32, i32)) -> &mut DrawChunk {
        let order = &mut self.order;
        self.by_cell.entry(cell).or_insert_with(|| {
            order.push(cell);
            DrawChunk::default()
        })
    }

    fn at(&mut self, point: Vector2) -> &mut DrawChunk {
        let cell = self.cell_of(point);
        self.for_cell(cell)
    }

    /// Cut a ribbon wherever it crosses into another chunk, with a disc at
    /// each cut so the seam comes out round.
    fn add_ribbon_pieces(&mut self, points: &[Vector2]) {
        let mut cell = self.cell_of(scaled(points[0] + points[1], 0.5));
        let mut piece = vec![points[0]];
        for s in 1..points.len() {
            let segment_cell = self.cell_of(scaled(points[s - 1] + points[s], 0.5));
            if segment_cell != cell {
                let chunk = self.for_cell(cell);
                chunk.ribbons.push(std::mem::replace(&mut piece, vec![points[s - 1]]));
                chunk.discs.push(points[s - 1]);
                cell = segment_cell;
            }
            piece.push(points[s]);
        }
        self.for_cell(cell).ribbons.push(piece);
    }

    fn into_ordered(mut self) -> Vec<((i32, i32), DrawChunk)> {
        self.order.iter().map(|cell| (*cell, self.by_cell.remove(cell).unwrap())).collect()
    }
}

/// Same triangles as the GDScript TriangleBatch's `add_segments()`.
#[derive(Default)]
struct TriangleBatch {
    points: Vec<Vector2>,
    colors: Vec<Color>,
    indices: Vec<i32>,
}

impl TriangleBatch {
    /// Soft edge added outside a line, standing in for anti-aliasing.
    const LINE_FEATHER: f64 = 1.0;

    fn add_segments(&mut self, segments: &[Vector2], color: Color, width: f64) {
        for pair in segments.chunks_exact(2) {
            self.add_line(pair[0], pair[1], color, width);
        }
    }

    fn add_line(&mut self, from: Vector2, to: Vector2, color: Color, width: f64) {
        let direction = to - from;
        if length_squared(direction) <= 0.0 {
            return;
        }
        let side = normalized(orthogonal(direction));
        let core = scaled(scaled(side, width), 0.5);
        let outer = scaled(side, width * 0.5 + Self::LINE_FEATHER);
        let clear = Color::from_rgba(color.r, color.g, color.b, 0.0);
        self.add_quad([from - core, to - core, to + core, from + core], color, color);
        self.add_quad([from + core, to + core, to + outer, from + outer], color, clear);
        self.add_quad([from - core, to - core, to - outer, from - outer], color, clear);
    }

    fn add_quad(&mut self, corners: [Vector2; 4], near_color: Color, far_color: Color) {
        let start = self.points.len() as i32;
        self.points.extend_from_slice(&corners);
        self.colors.extend_from_slice(&[near_color, near_color, far_color, far_color]);
        self.indices.extend_from_slice(&[start, start + 1, start + 2, start, start + 2, start + 3]);
    }
}
