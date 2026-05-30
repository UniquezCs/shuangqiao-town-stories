#!/usr/bin/env python3
"""Build and register the small high-priority icon pack."""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAW = Path("/Users/zhangcong/.codex/generated_images/019e66bb-f2c1-7db0-bcb0-a890311fea3f/ig_06b37ad1cea000ba016a199b190d8c8191a324584b73573fa2.png")
OUT = ROOT / "assets/generated/critical_icons_2026_05_29"

ICON_NAMES = (
    "pear",
    "cabbage_seed_packet",
    "cucumber_seed_packet",
    "tomato_seed_packet",
    "pear_seed_packet",
    "potato_seed_packet",
    "fertilizer_bag",
    "sickle",
    "warning_badge",
    "fine_penalty",
)


def res(path: Path) -> str:
    return "res://" + str(path.relative_to(ROOT))


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def remove_magenta(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            magenta_like = r > 120 and b > 120 and g < 155 and abs(r - b) < 90
            purple_fringe = r > 20 and b > 20 and g < 100 and abs(r - b) < 100 and g * 2 < max(r, b)
            if a < 24 or magenta_like or purple_fringe:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
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


def normalize_icon(frame: Image.Image, size: tuple[int, int] = (32, 32), fit: float = 0.9) -> Image.Image:
    frame = remove_magenta(frame)
    bbox = frame.getbbox()
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if bbox is None:
        return canvas
    frame = frame.crop(bbox)
    scale = min((size[0] * fit) / frame.width, (size[1] * fit) / frame.height)
    new_size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
    frame = frame.resize(new_size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(frame, ((size[0] - frame.width) // 2, (size[1] - frame.height) // 2))
    return remove_magenta(canvas)


def compose(frames: list[Image.Image], rows: int, cols: int, cell_size: tuple[int, int]) -> Image.Image:
    sheet = Image.new("RGBA", (cols * cell_size[0], rows * cell_size[1]), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        row, col = divmod(index, cols)
        sheet.alpha_composite(frame, (col * cell_size[0], row * cell_size[1]))
    return sheet


def build_pack() -> dict[str, str]:
    raw_dir = OUT / "raw"
    item_dir = OUT / "items"
    raw_dir.mkdir(parents=True, exist_ok=True)
    item_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(RAW, raw_dir / RAW.name)

    raw_img = Image.open(RAW)
    frames = split_grid(raw_img, 2, 5)
    icons = [normalize_icon(frame) for frame in frames]

    sheet_path = OUT / "critical_icons_sheet_32.png"
    compose(icons, 2, 5, (32, 32)).save(sheet_path)

    raw_clean_path = OUT / "critical_icons_raw_clean.png"
    compose([remove_magenta(frame) for frame in frames], 2, 5, (raw_img.width // 5, raw_img.height // 2)).save(raw_clean_path)

    paths: dict[str, str] = {}
    manifest_items: dict[str, dict[str, Any]] = {}
    for name, icon in zip(ICON_NAMES, icons):
        path = item_dir / f"{name}_32.png"
        icon.save(path)
        icon_path = res(path)
        paths[name] = icon_path
        manifest_items[name] = {
            "id": f"critical_icons.{name}",
            "type": _icon_type(name),
            "path": icon_path,
            "size": [32, 32],
            "anchor": "center",
            "collision": "none",
            "usage": _usage(name),
            "tags": ["icon", *_tags(name)],
        }

    manifest = {
        "schema_version": 2,
        "id": "pack.critical_icons_2026_05_29",
        "type": "icon_pack",
        "status": "available",
        "generated_at": "2026-05-29",
        "style": "warm 1990s Chinese rural pixel-art inventory and HUD icons",
        "raw": res(raw_dir / RAW.name),
        "raw_clean": res(raw_clean_path),
        "sheet": res(sheet_path),
        "rows": 2,
        "cols": 5,
        "cell_size": [32, 32],
        "items": manifest_items,
    }
    write_json(OUT / "manifest.json", manifest)
    return paths


def _icon_type(name: str) -> str:
    if name.endswith("_seed_packet") or name in {"pear", "fertilizer_bag"}:
        return "item_icon"
    if name == "sickle":
        return "tool_icon"
    return "ui_feedback_icon"


def _usage(name: str) -> list[str]:
    if name == "pear":
        return ["inventory_icon", "sellable_crop"]
    if name.endswith("_seed_packet"):
        return ["inventory_icon", "shop_item", "seed_item"]
    if name == "fertilizer_bag":
        return ["inventory_icon", "tool_consumable"]
    if name == "sickle":
        return ["hud_tool", "farm_harvest"]
    return ["chengguan_feedback", "ui_warning"]


def _tags(name: str) -> list[str]:
    if name.endswith("_seed_packet"):
        return ["seed", name.removesuffix("_seed_packet")]
    if name == "fertilizer_bag":
        return ["fertilizer"]
    if name == "sickle":
        return ["tool", "harvest"]
    if name in {"warning_badge", "fine_penalty"}:
        return ["warning", "chengguan"]
    return ["item", name]


def update_items(paths: dict[str, str]) -> None:
    path = ROOT / "configs/items.json"
    data = read_json(path)
    replacements = {
        "pear": paths["pear"],
        "cabbage_seed": paths["cabbage_seed_packet"],
        "cucumber_seed": paths["cucumber_seed_packet"],
        "tomato_seed": paths["tomato_seed_packet"],
        "pear_seed": paths["pear_seed_packet"],
        "potato_seed": paths["potato_seed_packet"],
        "fertilizer": paths["fertilizer_bag"],
    }
    for item_id, icon in replacements.items():
        if item_id in data:
            data[item_id]["icon"] = icon
    write_json(path, data)


def update_assets(paths: dict[str, str]) -> None:
    path = ROOT / "configs/assets.json"
    data = read_json(path)
    data["updated_at"] = "2026-05-29"
    data.setdefault("packs", {})["critical_icons_2026_05_29"] = {
        "id": "pack.critical_icons_2026_05_29",
        "type": "icon_pack",
        "status": "available",
        "path": "res://assets/generated/sprites/items",
        "notes": "Pear, per-crop seed packets, fertilizer, sickle, warning, and fine icons normalized to 32x32.",
    }

    items = data["items"]
    item_updates = {
        "item.pear": ("pear", ["inventory_icon", "sellable_crop"], ["item", "crop", "pear"], "implemented"),
        "item.fertilizer": ("fertilizer_bag", ["inventory_icon", "tool_consumable"], ["item", "fertilizer"], "implemented"),
    }
    for asset_id, (icon_name, usage, tags, status) in item_updates.items():
        entry = items[asset_id]
        entry["status"] = status
        entry["path"] = paths[icon_name]
        entry["size"] = [32, 32]
        entry["anchor"] = "center"
        entry["collision"] = "none"
        entry["usage"] = usage
        entry["tags"] = tags
        entry.pop("required_size", None)
        entry.pop("generation_need", None)
        entry.pop("notes", None)

    seed_entries = {
        "item.cabbage_seed": "cabbage_seed_packet",
        "item.cucumber_seed": "cucumber_seed_packet",
        "item.tomato_seed": "tomato_seed_packet",
        "item.pear_seed": "pear_seed_packet",
        "item.potato_seed": "potato_seed_packet",
    }
    for asset_id, icon_name in seed_entries.items():
        crop = asset_id.removeprefix("item.").removesuffix("_seed")
        items[asset_id] = {
            "type": "item_icon",
            "status": "implemented",
            "path": paths[icon_name],
            "size": [32, 32],
            "usage": ["inventory_icon", "shop_item", "seed_item"],
            "used_by": ["configs/items.json"],
            "anchor": "center",
            "collision": "none",
            "tags": ["item", "seed", crop],
        }

    if "item.generic_seed" in items:
        items["item.generic_seed"]["status"] = "available"
        items["item.generic_seed"]["notes"] = "Generic seed bag remains available as a fallback; active crop seeds now have dedicated icons."
        items["item.generic_seed"].pop("generation_need", None)

    tools = data["tools"]
    tools["tool.sickle"] = {
        "type": "tool_icon",
        "status": "available",
        "path": paths["sickle"],
        "size": [32, 32],
        "usage": ["hud_tool", "farm_harvest"],
        "anchor": "center",
        "collision": "none",
        "tags": ["tool", "sickle", "harvest"],
    }

    ui = data["ui"]
    ui["ui.penalty_warning"]["status"] = "available"
    ui["ui.penalty_warning"]["available_icons"] = {
        "warning": paths["warning_badge"],
        "fine": paths["fine_penalty"],
    }
    ui["ui.penalty_warning"]["size"] = [32, 32]
    ui["ui.penalty_warning"]["anchor"] = "center"
    ui["ui.penalty_warning"]["collision"] = "none"
    ui["ui.penalty_warning"]["tags"] = ["ui", "warning", "chengguan", "fine"]
    ui["ui.penalty_warning"].pop("required_size", None)
    ui["ui.penalty_warning"].pop("generation_need", None)

    write_json(path, data)


def main() -> None:
    paths = build_pack()
    update_items(paths)
    update_assets(paths)


if __name__ == "__main__":
    main()
