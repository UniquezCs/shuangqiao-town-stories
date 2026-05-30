#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CODEX_GENERATED = Path("/Users/zhangcong/.codex/generated_images/019e66bb-f2c1-7db0-bcb0-a890311fea3f")
SOURCE_DIR = ROOT / "assets" / "source" / "township_tiles_2026_05_30"
OUTPUT_ROOT = ROOT / "assets" / "generated" / "sprites" / "props" / "township"
ASSETS_JSON = ROOT / "configs" / "assets.json"


PACKS: dict[str, dict[str, Any]] = {
	"buildings": {
		"raw": CODEX_GENERATED / "ig_05e4167877072727016a19b4ec76b0819197d4450d58578d44.png",
		"source": SOURCE_DIR / "buildings_raw.png",
		"out_dir": OUTPUT_ROOT / "buildings",
		"items": [
			("school_classroom_block", "school classroom block with courtyard wall", (128, 96)),
			("hospital_outpatient", "hospital outpatient building", (128, 96)),
			("supply_coop_shop_row", "supply and marketing cooperative shop row", (128, 64)),
			("factory_workshop_smokestack", "factory workshop with smokestack", (160, 128)),
			("worker_dormitory", "worker dormitory block", (128, 64)),
			("residential_apartment", "residential brick apartment block", (128, 96)),
			("courtyard_house_cluster", "courtyard house cluster", (128, 96)),
			("police_government_office", "small police or government office", (96, 64)),
			("post_office", "small post office", (96, 64)),
			("bus_station_canopy", "bus station with platform canopy", (128, 64)),
			("cinema_cultural_hall", "cinema or cultural hall", (128, 96)),
			("grain_depot_warehouse", "grain depot warehouse", (128, 96)),
			("public_toilet_water_tap", "public toilet and water tap block", (64, 64)),
			("clinic_pharmacy_storefront", "clinic or pharmacy storefront", (96, 64)),
			("market_stall_row", "market stall row with awnings", (128, 64)),
			("village_house_garden", "village house with vegetable garden edge", (96, 96)),
		],
	},
	"infrastructure": {
		"raw": CODEX_GENERATED / "ig_05e4167877072727016a19b66d21148191a499973ca28c2c69.png",
		"source": SOURCE_DIR / "infrastructure_raw.png",
		"out_dir": OUTPUT_ROOT / "infrastructure",
		"items": [
			("asphalt_road_horizontal", "horizontal asphalt road segment", (96, 64)),
			("asphalt_road_vertical", "vertical asphalt road segment", (64, 96)),
			("asphalt_four_way_intersection", "asphalt four-way intersection", (96, 96)),
			("asphalt_t_junction", "asphalt T-junction", (96, 96)),
			("curved_asphalt_corner", "curved asphalt road corner", (96, 96)),
			("residential_alley", "narrow residential alley segment", (64, 96)),
			("dirt_village_road", "dirt village road segment", (96, 64)),
			("field_path_track", "field path or farm track", (96, 64)),
			("concrete_bridge_horizontal", "concrete bridge over canal", (128, 64)),
			("wooden_footbridge", "small wooden footbridge", (96, 64)),
			("canal_straight", "irrigation canal straight segment", (96, 64)),
			("canal_bend", "irrigation canal bend", (96, 96)),
			("brick_wall_gate_gap", "brick compound wall with gate gap", (96, 64)),
			("factory_gate_guard_booth", "factory gate with guard booth", (128, 64)),
			("institution_gate_pillars", "school or hospital gate pillars", (96, 64)),
			("utility_pole_lamp_cluster", "utility pole and street lamp cluster", (64, 64)),
		],
	},
	"daily_props": {
		"raw": CODEX_GENERATED / "ig_05e4167877072727016a1a9e902b408191af54ff2f11147174.png",
		"source": SOURCE_DIR / "daily_props_raw.png",
		"out_dir": OUTPUT_ROOT / "daily_props",
		"items": [
			("large_roadside_tree", "large roadside deciduous tree", (96, 96)),
			("courtyard_tree", "small courtyard tree", (64, 64)),
			("poplar_row_cluster", "poplar tree row cluster", (96, 64)),
			("shrub_cluster", "bush or shrub cluster", (64, 64)),
			("vegetable_stall_awning", "vegetable stall awning with baskets", (96, 64)),
			("bicycle_parking_cluster", "bicycle parking cluster", (96, 64)),
			("cargo_tricycle_cart", "cargo tricycle cart", (64, 64)),
			("old_truck", "small old truck", (96, 64)),
			("coal_pile_sacks", "coal pile with sacks", (64, 64)),
			("grain_sacks_stack", "stacked grain sacks", (64, 64)),
			("public_water_pump", "public water pump", (64, 64)),
			("laundry_line", "laundry line with clothes", (96, 64)),
			("utility_pole", "utility pole with wires", (64, 64)),
			("street_lamp", "street lamp", (32, 64)),
			("notice_board", "roadside notice board", (64, 64)),
			("haystack_farm_tools", "haystack and farm tools bundle", (64, 64)),
		],
	},
}


def main() -> None:
	SOURCE_DIR.mkdir(parents=True, exist_ok=True)
	for pack in PACKS.values():
		pack["out_dir"].mkdir(parents=True, exist_ok=True)
		if not pack["source"].exists():
			shutil.copy2(pack["raw"], pack["source"])
		_process_pack(pack)
	_update_asset_registry()
	_write_source_summary()


def _process_pack(pack: dict[str, Any]) -> None:
	image = Image.open(pack["source"]).convert("RGBA")
	width, height = image.size
	cell_w = width // 4
	cell_h = height // 4
	margin = 8

	for index, (slug, _description, target_size) in enumerate(pack["items"]):
		row = index // 4
		col = index % 4
		cell = image.crop((
			col * cell_w + margin,
			row * cell_h + margin,
			(col + 1) * cell_w - margin,
			(row + 1) * cell_h - margin,
		))
		clean = _remove_magenta(cell)
		normalized = _normalize_to_canvas(clean, target_size)
		normalized.save(pack["out_dir"] / f"{slug}.png")


def _remove_magenta(image: Image.Image) -> Image.Image:
	pixels = image.load()
	visited: set[tuple[int, int]] = set()
	queue: deque[tuple[int, int]] = deque()

	for x in range(image.width):
		for y in (0, image.height - 1):
			if _is_magenta_key(pixels[x, y]):
				queue.append((x, y))
				visited.add((x, y))
	for y in range(image.height):
		for x in (0, image.width - 1):
			if (x, y) not in visited and _is_magenta_key(pixels[x, y]):
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
			if _is_magenta_key(pixels[nx, ny]):
				visited.add((nx, ny))
				queue.append((nx, ny))

	for _pass in range(2):
		to_clear: list[tuple[int, int]] = []
		for y in range(1, image.height - 1):
			for x in range(1, image.width - 1):
				if pixels[x, y][3] == 0 or not _is_magenta_key(pixels[x, y]):
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


def _is_magenta_key(pixel: tuple[int, int, int, int]) -> bool:
	r, g, b, a = pixel
	return a > 0 and r > 130 and b > 110 and g < 145 and r + b > g * 3


def _normalize_to_canvas(image: Image.Image, target_size: tuple[int, int]) -> Image.Image:
	alpha = image.getchannel("A")
	bbox = alpha.getbbox()
	canvas = Image.new("RGBA", target_size, (0, 0, 0, 0))
	if bbox is None:
		return canvas

	trimmed = image.crop(bbox)
	max_w = max(1, target_size[0] - 8)
	max_h = max(1, target_size[1] - 8)
	scale = min(max_w / trimmed.width, max_h / trimmed.height, 1.0)
	new_size = (
		max(1, int(trimmed.width * scale)),
		max(1, int(trimmed.height * scale)),
	)
	resized = trimmed.resize(new_size, Image.Resampling.NEAREST)
	x = (target_size[0] - resized.width) // 2
	y = (target_size[1] - resized.height) // 2
	canvas.alpha_composite(resized, (x, y))
	return canvas


def _update_asset_registry() -> None:
	data = json.loads(ASSETS_JSON.read_text(encoding="utf-8"))
	town_props = data.setdefault("town_props", {})

	for category, pack in PACKS.items():
		for slug, description, target_size in pack["items"]:
			asset_id = f"prop.township.{slug}"
			rel_path = (pack["out_dir"] / f"{slug}.png").relative_to(ROOT)
			town_props[asset_id] = {
				"id": asset_id,
				"type": "prop",
				"status": "available",
				"path": "res://" + rel_path.as_posix(),
				"size": list(target_size),
				"anchor": "center",
				"collision": "none",
				"usage": [
					"township_map_reference",
					"editor_placed_town_decoration",
				],
				"tags": [
					"township",
					category,
					"topdown_pixel",
					"1990s_chinese_town",
				],
				"notes": description,
			}

	data["updated_at"] = "2026-05-30"
	ASSETS_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_source_summary() -> None:
	entries: list[dict[str, Any]] = []
	for category, pack in PACKS.items():
		for slug, description, target_size in pack["items"]:
			entries.append({
				"id": f"prop.township.{slug}",
				"category": category,
				"description": description,
				"size": list(target_size),
				"output": "res://" + (pack["out_dir"] / f"{slug}.png").relative_to(ROOT).as_posix(),
			})
	(SOURCE_DIR / "township_asset_pack_summary.json").write_text(
		json.dumps({
			"source": "Generated from three 4x4 top-down pixel-art sheets.",
			"final_assets": entries,
			"note": "Final game-ready PNGs are stored under assets/generated/sprites/props/township. This source summary is intentionally outside assets/generated.",
		}, ensure_ascii=False, indent=2) + "\n",
		encoding="utf-8",
	)


if __name__ == "__main__":
	main()
