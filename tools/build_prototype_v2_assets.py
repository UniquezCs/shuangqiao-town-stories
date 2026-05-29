#!/usr/bin/env python3
"""Normalize generated prototype v2 art into Godot-ready asset files."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GEN_DIR = Path("/Users/zhangcong/.codex/generated_images/019e6f0f-656f-78f2-8e70-808e59466a9e")
OUT = ROOT / "assets/generated/prototype_v2"

RAW_SOURCES = {
    "student_walk_raw.png": GEN_DIR / "ig_001d0683d216f1b7016a18730742a48191953233f6602d9f76.png",
    "worker_walk_raw.png": GEN_DIR / "ig_001d0683d216f1b7016a1873a7468c8191bef098868227da5e.png",
    "ui_feedback_icons_raw.png": GEN_DIR / "ig_001d0683d216f1b7016a187434708c81919ec6d70b4a51480e.png",
    "farm_home_objects_raw.png": GEN_DIR / "ig_001d0683d216f1b7016a1874a497488191bc7ef56e29cd00c4.png",
}

DIRECTIONS = ("walk_down", "walk_left", "walk_right", "walk_up")

UI_ICON_NAMES = (
    "apple",
    "apple_seed_packet",
    "cash_coins",
    "time_clock",
    "school_gate",
    "factory_gate",
    "backpack",
    "price_tag",
    "price_up",
    "price_down",
    "purchase_bubble",
    "refusal_bubble",
    "question_bubble",
    "sold_out_basket",
    "daily_summary_ledger",
    "stall_location_marker",
)

FARM_OBJECTS = (
    ("rural_house_facade", (256, 128)),
    ("house_doorway", (128, 128)),
    ("apple_tree", (96, 96)),
    ("farm_empty", (64, 64)),
    ("farm_seeded", (64, 64)),
    ("farm_growing", (64, 64)),
    ("farm_ready", (64, 64)),
    ("seed_shop_stand", (128, 96)),
    ("bed_roll", (64, 64)),
    ("ledger_table", (64, 64)),
    ("water_jar", (64, 64)),
    ("bamboo_fence", (128, 64)),
    ("dirt_road_sign", (64, 64)),
    ("courtyard_path_tile", (64, 64)),
    ("apple_basket_pile", (64, 64)),
    ("scene_exit_marker", (64, 64)),
)


def res(path: Path) -> str:
    return "res://" + str(path.relative_to(ROOT))


def remove_magenta(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if r > 140 and b > 140 and g < 170 and abs(r - b) < 130:
                pixels[x, y] = (r, g, b, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return rgba


def remove_magenta_fringe(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            magenta_like = r > 50 and b > 50 and g < 90 and abs(r - b) < 120
            if a < 96 or magenta_like:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def split_grid(img: Image.Image, rows: int, cols: int) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for row in range(rows):
        y0 = round(row * img.height / rows)
        y1 = round((row + 1) * img.height / rows)
        for col in range(cols):
            x0 = round(col * img.width / cols)
            x1 = round((col + 1) * img.width / cols)
            frames.append(img.crop((x0, y0, x1, y1)))
    return frames


def normalize_cell(frame: Image.Image, size: tuple[int, int], fit: float = 0.9, align: str = "center") -> Image.Image:
    frame = remove_magenta(frame)
    bbox = frame.getbbox()
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if bbox is None:
        return canvas

    frame = frame.crop(bbox)
    max_w = max(1, int(size[0] * fit))
    max_h = max(1, int(size[1] * fit))
    scale = min(max_w / frame.width, max_h / frame.height)
    new_size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
    frame = frame.resize(new_size, Image.Resampling.LANCZOS)
    x = (size[0] - frame.width) // 2
    if align in {"bottom", "feet"}:
        y = size[1] - frame.height - max(1, round(size[1] * 0.04))
    else:
        y = (size[1] - frame.height) // 2
    canvas.alpha_composite(frame, (x, y))
    return remove_magenta_fringe(canvas)


def compose(frames: list[Image.Image], rows: int, cols: int, cell_size: tuple[int, int]) -> Image.Image:
    sheet = Image.new("RGBA", (cols * cell_size[0], rows * cell_size[1]), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        row, col = divmod(index, cols)
        sheet.alpha_composite(frame, (col * cell_size[0], row * cell_size[1]))
    return sheet


def write_spriteframes(path: Path, texture_path: Path) -> None:
    lines: list[str] = [
        '[gd_resource type="SpriteFrames" format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{res(texture_path)}" id="1_sheet"]',
        "",
    ]
    sub_ids: list[str] = []
    for row, direction in enumerate(DIRECTIONS):
        for col in range(8):
            sub_id = f"AtlasTexture_{direction}_{col + 1}"
            sub_ids.append(sub_id)
            lines.extend(
                [
                    f'[sub_resource type="AtlasTexture" id="{sub_id}"]',
                    'atlas = ExtResource("1_sheet")',
                    f"region = Rect2({col * 48}, {row * 64}, 48, 64)",
                    "",
                ]
            )

    lines.append("[resource]")
    lines.append("animations = [")
    for row, direction in enumerate(DIRECTIONS):
        if row:
            lines.append(", {")
        else:
            lines.append("{")
        lines.append('"frames": [')
        for col in range(8):
            if col:
                lines.append(", {")
            else:
                lines.append("{")
            lines.append('"duration": 1.0,')
            lines.append(f'"texture": SubResource("{sub_ids[row * 8 + col]}")')
            lines.append("}")
        lines.append("],")
        lines.append('"loop": true,')
        lines.append(f'"name": &"{direction}",')
        lines.append('"speed": 8.0')
        lines.append("}")
    lines.append("]")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_tile_set(path: Path, texture_path: Path, cols: int, rows: int) -> None:
    lines = [
        '[gd_resource type="TileSet" format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{res(texture_path)}" id="1_tex"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_0"]',
        'texture = ExtResource("1_tex")',
        "texture_region_size = Vector2i(32, 32)",
    ]
    for y in range(rows):
        for x in range(cols):
            lines.append(f"{x}:{y}/0 = 0")
    lines.extend(
        [
            "",
            "[resource]",
            "tile_size = Vector2i(32, 32)",
            'sources/0 = SubResource("TileSetAtlasSource_0")',
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_character(name: str, raw_path: Path, manifest: dict) -> None:
    out_dir = OUT / "characters"
    frame_dir = out_dir / f"{name}_frames"
    frame_dir.mkdir(parents=True, exist_ok=True)

    raw = Image.open(raw_path)
    frames = [
        normalize_cell(frame, (48, 64), fit=0.92, align="feet")
        for frame in split_grid(raw, 4, 8)
    ]
    sheet_path = out_dir / f"{name}_walk_4dir_8f_48x64.png"
    compose(frames, 4, 8, (48, 64)).save(sheet_path)
    for row, direction in enumerate(DIRECTIONS):
        for col in range(8):
            frames[row * 8 + col].save(frame_dir / f"{direction}_{col + 1}.png")
    spriteframes_path = out_dir / f"{name}_walk_spriteframes_48x64.tres"
    write_spriteframes(spriteframes_path, sheet_path)
    manifest["characters"][name] = {
        "sheet": res(sheet_path),
        "spriteframes": res(spriteframes_path),
        "frames": 32,
        "cell_size": [48, 64],
        "animations": list(DIRECTIONS),
    }


def build_ui_icons(manifest: dict) -> None:
    out_dir = OUT / "ui"
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(RAW_SOURCES["ui_feedback_icons_raw.png"])
    frames = [
        normalize_cell(frame, (32, 32), fit=0.86)
        for frame in split_grid(raw, 4, 4)
    ]
    sheet_path = out_dir / "ui_feedback_icons_32.png"
    compose(frames, 4, 4, (32, 32)).save(sheet_path)
    items = {}
    for name, frame in zip(UI_ICON_NAMES, frames):
        path = out_dir / f"{name}_32.png"
        frame.save(path)
        items[name] = res(path)
    manifest["ui"] = {
        "sheet": res(sheet_path),
        "cell_size": [32, 32],
        "items": items,
    }


def build_farm_objects(manifest: dict) -> None:
    out_dir = OUT / "objects"
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(RAW_SOURCES["farm_home_objects_raw.png"])
    frames = split_grid(raw, 4, 4)
    items = {}
    for (name, size), frame in zip(FARM_OBJECTS, frames):
        normalized = normalize_cell(frame, size, fit=0.9, align="feet")
        path = out_dir / f"{name}_{size[0]}x{size[1]}.png"
        normalized.save(path)
        items[name] = {"path": res(path), "size": list(size)}
    manifest["objects"] = items


def main() -> None:
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    for name, source in RAW_SOURCES.items():
        shutil.copy2(source, OUT / "raw" / name)

    manifest: dict = {
        "name": "prototype_v2_art_pack",
        "style": "clean cute pixel art, warm 1990s Chinese rural town management sim",
        "baseline": {
            "tile_size": [32, 32],
            "character_frame_size": [48, 64],
            "filter": "nearest-neighbor in Godot imports",
        },
        "raw": {name: res(OUT / "raw" / name) for name in RAW_SOURCES},
        "characters": {
            "vendor": {
                "sheet": "res://assets/generated/prototype_v1_32/characters/vendor_walk_4dir_8f_48x64.png",
                "spriteframes": "res://assets/generated/prototype_v1_32/characters/vendor_walk_spriteframes_48x64.tres",
                "frames": 32,
                "cell_size": [48, 64],
                "animations": list(DIRECTIONS),
            }
        },
        "tilesets": {
            "rural_town_32": {
                "atlas": "res://assets/generated/tilesets/rural_town_32/rural_town_tiles_32.png",
                "tileset": "res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres",
                "tile_size": [32, 32],
            },
            "street_stall_props_v2_sheet": "res://assets/generated/tilesets/street_stall_props_v2.png",
            "town_buildings_props_v2_sheet": "res://assets/generated/tilesets/town_buildings_props_v2.png",
            "street_stall_cutouts": "res://assets/generated/props/street_stall_props_v2_cutouts/manifest.json",
        },
    }

    build_character("student", RAW_SOURCES["student_walk_raw.png"], manifest)
    build_character("worker", RAW_SOURCES["worker_walk_raw.png"], manifest)
    build_ui_icons(manifest)
    build_farm_objects(manifest)

    ui_tileset = OUT / "ui/ui_feedback_icons_tileset_32.tres"
    write_tile_set(ui_tileset, OUT / "ui/ui_feedback_icons_32.png", 4, 4)
    manifest["ui"]["tileset"] = res(ui_tileset)

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
