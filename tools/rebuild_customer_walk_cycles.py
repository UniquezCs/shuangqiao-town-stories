#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
GEN_DIR = Path("/Users/zhangcong/.codex/generated_images/019e66bb-f2c1-7db0-bcb0-a890311fea3f")
SOURCE_DIR = ROOT / "assets" / "source" / "customer_walk_rework_2026_05_31"
OUT_DIR = ROOT / "assets" / "generated" / "sprites" / "characters"
ASSETS_JSON = ROOT / "configs" / "assets.json"

CELL_SIZE = (48, 64)
TARGET_BODY_HEIGHT = 48
ROWS = 4
COLS = 8
DIRECTIONS = ("walk_down", "walk_left", "walk_right", "walk_up")
GAIT_SEQUENCE = (
	"standing",
	"left_low",
	"right_low",
	"left_high",
	"right_high",
	"left_lower",
	"right_lower",
	"standing",
)

RAW_SOURCES = {
	"student": GEN_DIR / "ig_05e4167877072727016a1b10902bac8191aac5ede9f325fcdd.png",
	"worker": GEN_DIR / "ig_05e4167877072727016a1b110346f08191b7be4ad00da7c264.png",
}

BACK_ROW_SOURCES = {
	"student": GEN_DIR / "ig_05e4167877072727016a1b1bc98a6c819189d6121857bf0fab.png",
	"worker": GEN_DIR / "ig_05e4167877072727016a1b1cc9a7c48191bb44a933743667e6.png",
}


def main() -> None:
	SOURCE_DIR.mkdir(parents=True, exist_ok=True)
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	report: dict[str, Any] = {
		"frame_size": list(CELL_SIZE),
		"directions": list(DIRECTIONS),
		"gait_sequence": list(GAIT_SEQUENCE),
		"characters": {},
	}
	for name, raw_path in RAW_SOURCES.items():
		source_path = SOURCE_DIR / f"{name}_walk_raw.png"
		back_source_path = SOURCE_DIR / f"{name}_walk_up_raw.png"
		shutil.copy2(raw_path, source_path)
		shutil.copy2(BACK_ROW_SOURCES[name], back_source_path)
		report["characters"][name] = _build_character(name, source_path, back_source_path)
	_write_spriteframes(OUT_DIR / "student_walk_spriteframes_48x64.tres", OUT_DIR / "student_walk_4dir_8f_48x64.png")
	_write_spriteframes(OUT_DIR / "worker_walk_spriteframes_48x64.tres", OUT_DIR / "worker_walk_4dir_8f_48x64.png")
	_update_asset_registry()
	_write_preview()
	(SOURCE_DIR / "customer_walk_rework_report.json").write_text(
		json.dumps(report, ensure_ascii=False, indent=2) + "\n",
		encoding="utf-8",
	)


def _build_character(name: str, source_path: Path, back_source_path: Path) -> dict[str, Any]:
	raw = Image.open(source_path).convert("RGBA")
	back_raw = Image.open(back_source_path).convert("RGBA")
	frames = [_remove_detached_floor_noise(_remove_magenta(frame)) for frame in _split_grid(raw)]
	back_frames = [_remove_detached_floor_noise(_remove_magenta(frame)) for frame in _split_back_grid(back_raw)]
	for col in range(COLS):
		frames[2 * COLS + col] = frames[1 * COLS + col].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
	frames[3 * COLS:4 * COLS] = back_frames
	groups = ["main"] * (3 * COLS) + ["back"] * COLS
	normalized, metrics = _normalize_shared(frames, groups)
	sheet = _compose_sheet(normalized)
	sheet_path = OUT_DIR / f"{name}_walk_4dir_8f_48x64.png"
	sheet.save(sheet_path)
	return {
		"source": _res(source_path),
		"back_source": _res(back_source_path),
		"sheet": _res(sheet_path),
		"frames": len(normalized),
		"group_scales": metrics["group_scales"],
		"group_max_source_bbox": metrics["group_max_source_bbox"],
		"feet_baseline": metrics["feet_baseline"],
	}


def _split_grid(raw: Image.Image) -> list[Image.Image]:
	frames: list[Image.Image] = []
	for row in range(ROWS):
		y0 = round(row * raw.height / ROWS)
		y1 = round((row + 1) * raw.height / ROWS)
		for col in range(COLS):
			x0 = round(col * raw.width / COLS)
			x1 = round((col + 1) * raw.width / COLS)
			frames.append(raw.crop((x0, y0, x1, y1)))
	return frames


def _split_back_grid(raw: Image.Image) -> list[Image.Image]:
	frames: list[Image.Image] = []
	for row in range(2):
		y0 = round(row * raw.height / 2)
		y1 = round((row + 1) * raw.height / 2)
		for col in range(4):
			x0 = round(col * raw.width / 4)
			x1 = round((col + 1) * raw.width / 4)
			frames.append(raw.crop((x0, y0, x1, y1)))
	return frames


def _remove_magenta(image: Image.Image) -> Image.Image:
	image = image.convert("RGBA")
	pixels = image.load()
	queue: deque[tuple[int, int]] = deque()
	visited: set[tuple[int, int]] = set()
	for x in range(image.width):
		for y in (0, image.height - 1):
			if _is_magenta(pixels[x, y]):
				queue.append((x, y))
				visited.add((x, y))
	for y in range(image.height):
		for x in (0, image.width - 1):
			if (x, y) not in visited and _is_magenta(pixels[x, y]):
				queue.append((x, y))
				visited.add((x, y))
	while queue:
		x, y = queue.popleft()
		r, g, b, _a = pixels[x, y]
		pixels[x, y] = (r, g, b, 0)
		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if nx < 0 or ny < 0 or nx >= image.width or ny >= image.height:
				continue
			if (nx, ny) in visited:
				continue
			if _is_magenta(pixels[nx, ny]):
				visited.add((nx, ny))
				queue.append((nx, ny))
	for _pass in range(2):
		to_clear: list[tuple[int, int]] = []
		for y in range(1, image.height - 1):
			for x in range(1, image.width - 1):
				if pixels[x, y][3] == 0 or not _is_magenta(pixels[x, y]):
					continue
				if (
					pixels[x + 1, y][3] == 0
					or pixels[x - 1, y][3] == 0
					or pixels[x, y + 1][3] == 0
					or pixels[x, y - 1][3] == 0
				):
					to_clear.append((x, y))
		for x, y in to_clear:
			r, g, b, _a = pixels[x, y]
			pixels[x, y] = (r, g, b, 0)
	return image


def _is_magenta(pixel: tuple[int, int, int, int]) -> bool:
	r, g, b, a = pixel
	return a > 0 and r > 130 and b > 120 and g < 150 and r + b > g * 3


def _remove_detached_floor_noise(image: Image.Image) -> Image.Image:
	alpha = image.getchannel("A")
	visited: set[tuple[int, int]] = set()
	components: list[list[tuple[int, int]]] = []
	for y in range(image.height):
		for x in range(image.width):
			if (x, y) in visited or alpha.getpixel((x, y)) == 0:
				continue
			component: list[tuple[int, int]] = []
			queue: deque[tuple[int, int]] = deque([(x, y)])
			visited.add((x, y))
			while queue:
				cx, cy = queue.popleft()
				component.append((cx, cy))
				for nx in range(cx - 1, cx + 2):
					for ny in range(cy - 1, cy + 2):
						if nx == cx and ny == cy:
							continue
						if nx < 0 or ny < 0 or nx >= image.width or ny >= image.height:
							continue
						if (nx, ny) in visited or alpha.getpixel((nx, ny)) == 0:
							continue
						visited.add((nx, ny))
						queue.append((nx, ny))
			components.append(component)

	if not components:
		return image
	main = max(components, key=len)
	main_bbox = _component_bbox(main)
	main_height = max(1, main_bbox[3] - main_bbox[1])
	lower_noise_y = main_bbox[1] + int(main_height * 0.72)
	keep_set: set[tuple[int, int]] = set()
	for component in components:
		bbox = _component_bbox(component)
		width = bbox[2] - bbox[0]
		height = bbox[3] - bbox[1]
		area = len(component)
		is_tiny_floor_noise = bbox[1] >= lower_noise_y and height <= 12 and area <= 500 and width >= height * 1.3
		if not is_tiny_floor_noise:
			keep_set.update(component)
	clean = Image.new("RGBA", image.size, (0, 0, 0, 0))
	source = image.load()
	target = clean.load()
	for x, y in keep_set:
		target[x, y] = source[x, y]
	return clean


def _component_bbox(component: list[tuple[int, int]]) -> tuple[int, int, int, int]:
	min_x = min(x for x, _y in component)
	min_y = min(y for _x, y in component)
	max_x = max(x for x, _y in component) + 1
	max_y = max(y for _x, y in component) + 1
	return min_x, min_y, max_x, max_y


def _normalize_shared(frames: list[Image.Image], groups: list[str]) -> tuple[list[Image.Image], dict[str, Any]]:
	bboxes = [frame.getchannel("A").getbbox() for frame in frames]
	non_empty = [bbox for bbox in bboxes if bbox is not None]
	if not non_empty:
		return [Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0)) for _ in frames], {
			"group_scales": {},
			"group_max_source_bbox": {},
			"feet_baseline": CELL_SIZE[1] - 3,
		}

	target_w = CELL_SIZE[0] - 8
	target_h = TARGET_BODY_HEIGHT
	baseline = CELL_SIZE[1] - 3
	group_scales: dict[str, float] = {}
	group_max_bbox: dict[str, tuple[int, int]] = {}

	for group in sorted(set(groups)):
		group_boxes = [bbox for bbox, item_group in zip(bboxes, groups) if item_group == group and bbox is not None]
		if not group_boxes:
			group_scales[group] = 1.0
			group_max_bbox[group] = (0, 0)
			continue
		max_w = max(bbox[2] - bbox[0] for bbox in group_boxes)
		max_h = max(bbox[3] - bbox[1] for bbox in group_boxes)
		group_scales[group] = min(target_w / max_w, target_h / max_h)
		group_max_bbox[group] = (max_w, max_h)

	normalized: list[Image.Image] = []
	for frame, bbox, group in zip(frames, bboxes, groups):
		canvas = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
		if bbox is not None:
			cropped = frame.crop(bbox)
			scale = group_scales[group]
			size = (
				max(1, round(cropped.width * scale)),
				max(1, round(cropped.height * scale)),
			)
			resized = cropped.resize(size, Image.Resampling.LANCZOS)
			x = (CELL_SIZE[0] - resized.width) // 2
			y = baseline - resized.height
			canvas.alpha_composite(_clean_alpha_fringe(resized), (x, y))
		normalized.append(_clean_alpha_fringe(canvas))
	for row in range(ROWS):
		normalized[row * COLS + 7] = normalized[row * COLS].copy()
	for col in range(COLS):
		normalized[2 * COLS + col] = normalized[1 * COLS + col].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
	return normalized, {
		"group_scales": group_scales,
		"group_max_source_bbox": {key: list(value) for key, value in group_max_bbox.items()},
		"feet_baseline": baseline,
	}


def _clean_alpha_fringe(image: Image.Image) -> Image.Image:
	image = image.convert("RGBA")
	pixels = image.load()
	for y in range(image.height):
		for x in range(image.width):
			r, g, b, a = pixels[x, y]
			if a < 64 or _is_magenta((r, g, b, max(a, 1))):
				pixels[x, y] = (r, g, b, 0)
	return image


def _compose_sheet(frames: list[Image.Image]) -> Image.Image:
	sheet = Image.new("RGBA", (COLS * CELL_SIZE[0], ROWS * CELL_SIZE[1]), (0, 0, 0, 0))
	for index, frame in enumerate(frames):
		row, col = divmod(index, COLS)
		sheet.alpha_composite(frame, (col * CELL_SIZE[0], row * CELL_SIZE[1]))
	return sheet


def _write_spriteframes(path: Path, texture_path: Path) -> None:
	lines: list[str] = [
		'[gd_resource type="SpriteFrames" format=3]',
		"",
		f'[ext_resource type="Texture2D" path="{_res(texture_path)}" id="1_sheet"]',
		"",
	]
	sub_ids: list[str] = []
	for row, direction in enumerate(DIRECTIONS):
		for col in range(COLS):
			sub_id = f"AtlasTexture_{direction}_{col + 1}"
			sub_ids.append(sub_id)
			lines.extend([
				f'[sub_resource type="AtlasTexture" id="{sub_id}"]',
				'resource_name = "%s_%d"' % (direction, col + 1),
				'region = Rect2(%d, %d, %d, %d)' % (col * CELL_SIZE[0], row * CELL_SIZE[1], CELL_SIZE[0], CELL_SIZE[1]),
				'filter_clip = true',
				'atlas = ExtResource("1_sheet")',
				"",
			])
	lines.append("[resource]")
	lines.append("animations = [")
	for row, direction in enumerate(DIRECTIONS):
		lines.append("{")
		lines.append('"frames": [')
		for col in range(COLS):
			lines.append("{")
			lines.append('"duration": 1.0,')
			lines.append(f'"texture": SubResource("{sub_ids[row * COLS + col]}")')
			lines.append("}%s" % ("," if col < COLS - 1 else ""))
		lines.append("],")
		lines.append('"loop": true,')
		lines.append(f'"name": &"{direction}",')
		lines.append('"speed": 8.0')
		lines.append("}%s" % ("," if row < ROWS - 1 else ""))
	lines.append("]")
	path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _update_asset_registry() -> None:
	data = json.loads(ASSETS_JSON.read_text(encoding="utf-8"))
	for asset_id, name in (
		("character.student_customer", "student"),
		("character.worker_customer", "worker"),
	):
		entry = data["characters"][asset_id]
		entry["status"] = "implemented"
		entry["current_spriteframes"] = _res(OUT_DIR / f"{name}_walk_spriteframes_48x64.tres")
		entry["available_sheet"] = _res(OUT_DIR / f"{name}_walk_4dir_8f_48x64.png")
		entry["frame_size"] = list(CELL_SIZE)
		entry["animations"] = list(DIRECTIONS)
		entry["frames_per_direction"] = COLS
		entry["gait_sequence"] = list(GAIT_SEQUENCE)
		entry["notes"] = "Rebuilt 2026-05-31 with shared scale, stable feet baseline, and full-frame containment."
	data["updated_at"] = "2026-05-31"
	ASSETS_JSON.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def _write_preview() -> None:
	student = Image.open(OUT_DIR / "student_walk_4dir_8f_48x64.png").convert("RGBA")
	worker = Image.open(OUT_DIR / "worker_walk_4dir_8f_48x64.png").convert("RGBA")
	preview = Image.new("RGBA", (student.width, student.height * 2 + 32), (36, 32, 30, 255))
	draw = ImageDraw.Draw(preview)
	draw.text((4, 4), "student_walk_4dir_8f_48x64", fill=(230, 220, 200, 255))
	preview.alpha_composite(student, (0, 16))
	draw.text((4, student.height + 20), "worker_walk_4dir_8f_48x64", fill=(230, 220, 200, 255))
	preview.alpha_composite(worker, (0, student.height + 32))
	preview.convert("RGB").save(SOURCE_DIR / "customer_walk_rework_preview.png")


def _res(path: Path) -> str:
	return "res://" + path.relative_to(ROOT).as_posix()


if __name__ == "__main__":
	main()
