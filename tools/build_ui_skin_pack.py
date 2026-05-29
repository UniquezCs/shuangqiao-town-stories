#!/usr/bin/env python3
"""Slice generated backpack and shop UI art into Godot-ready PNG assets."""

from __future__ import annotations

import json
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = Path("/Users/zhangcong/.codex/generated_images/019e66bb-f2c1-7db0-bcb0-a890311fea3f")
OUT = ROOT / "assets/generated/ui_skins_2026_05_29"


@dataclass(frozen=True)
class AssetSpec:
    name: str
    size: tuple[int, int]
    fit: float = 0.9


@dataclass(frozen=True)
class SheetSpec:
    key: str
    raw_name: str
    rows: int
    cols: int
    sheet_cell: tuple[int, int]
    assets: tuple[AssetSpec, ...]


BACKPACK = SheetSpec(
    key="backpack",
    raw_name="ig_06b37ad1cea000ba016a188dfaad9c8191adc06e5e2cc7a2bf.png",
    rows=4,
    cols=4,
    sheet_cell=(96, 96),
    assets=(
        AssetSpec("panel_frame", (320, 256), 0.96),
        AssetSpec("inner_paper_panel", (160, 160), 0.92),
        AssetSpec("slot_empty", (64, 64), 0.92),
        AssetSpec("slot_highlighted", (64, 64), 0.92),
        AssetSpec("slot_locked", (64, 64), 0.92),
        AssetSpec("quantity_badge", (72, 48), 0.9),
        AssetSpec("coin_cash_badge", (96, 64), 0.9),
        AssetSpec("title_plaque", (192, 64), 0.95),
        AssetSpec("close_button", (64, 64), 0.9),
        AssetSpec("tab_backpack", (128, 64), 0.92),
        AssetSpec("tab_crop", (128, 64), 0.92),
        AssetSpec("tab_tool", (128, 64), 0.92),
        AssetSpec("scroll_divider", (48, 160), 0.95),
        AssetSpec("backpack_emblem", (96, 96), 0.9),
        AssetSpec("item_detail_card", (192, 128), 0.94),
        AssetSpec("confirm_button", (128, 64), 0.92),
    ),
)

SHOP = SheetSpec(
    key="shop",
    raw_name="ig_06b37ad1cea000ba016a188f009a648191ac16fd46059f8023.png",
    rows=4,
    cols=4,
    sheet_cell=(96, 96),
    assets=(
        AssetSpec("panel_frame", (320, 256), 0.96),
        AssetSpec("goods_shelf_card", (160, 160), 0.92),
        AssetSpec("seed_packet_card", (160, 160), 0.92),
        AssetSpec("crop_basket_card", (160, 160), 0.92),
        AssetSpec("price_tag_badge", (128, 64), 0.9),
        AssetSpec("sold_out_stamp", (96, 96), 0.9),
        AssetSpec("buy_button", (144, 64), 0.92),
        AssetSpec("disabled_buy_button", (144, 64), 0.92),
        AssetSpec("upgrade_card", (192, 144), 0.94),
        AssetSpec("backpack_upgrade_icon", (96, 96), 0.9),
        AssetSpec("stall_upgrade_icon", (96, 96), 0.9),
        AssetSpec("coin_stack_badge", (96, 96), 0.9),
        AssetSpec("awning_header", (224, 96), 0.95),
        AssetSpec("close_button", (64, 64), 0.9),
        AssetSpec("stock_badge", (128, 64), 0.9),
        AssetSpec("receipt_paper", (128, 160), 0.92),
    ),
)


def res(path: Path) -> str:
    return "res://" + str(path.relative_to(ROOT))


def remove_magenta(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            magenta_like = r > 90 and b > 90 and g < 130 and abs(r - b) < 105
            purple_fringe = r > 18 and b > 18 and g < 80 and abs(r - b) < 90 and g * 2 < max(r, b)
            if a < 24 or magenta_like or purple_fringe:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return rgba


def trim(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


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


def normalize(frame: Image.Image, size: tuple[int, int], fit: float) -> Image.Image:
    frame = trim(remove_magenta(frame))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if frame.getbbox() is None:
        return canvas
    max_w = max(1, int(size[0] * fit))
    max_h = max(1, int(size[1] * fit))
    scale = min(max_w / frame.width, max_h / frame.height)
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


def build(spec: SheetSpec, manifest: dict) -> None:
    out_dir = OUT / spec.key
    raw_dir = out_dir / "raw"
    items_dir = out_dir / "items"
    raw_dir.mkdir(parents=True, exist_ok=True)
    items_dir.mkdir(parents=True, exist_ok=True)

    raw_path = RAW_DIR / spec.raw_name
    shutil.copy2(raw_path, raw_dir / spec.raw_name)

    raw = Image.open(raw_path)
    frames = split_grid(raw, spec.rows, spec.cols)
    cleaned = [remove_magenta(frame) for frame in frames]
    normalized_sheet_frames = [
        normalize(frame, spec.sheet_cell, 0.88)
        for frame in frames
    ]

    clean_sheet_path = out_dir / f"{spec.key}_raw_clean.png"
    compose(cleaned, spec.rows, spec.cols, (raw.width // spec.cols, raw.height // spec.rows)).save(clean_sheet_path)

    sheet_path = out_dir / f"{spec.key}_components_sheet.png"
    compose(normalized_sheet_frames, spec.rows, spec.cols, spec.sheet_cell).save(sheet_path)

    items: dict[str, dict[str, object]] = {}
    for asset, frame in zip(spec.assets, frames):
        item = normalize(frame, asset.size, asset.fit)
        item_path = items_dir / f"{asset.name}.png"
        item.save(item_path)
        items[asset.name] = {
            "path": res(item_path),
            "size": list(asset.size),
        }

    manifest[spec.key] = {
        "raw": res(raw_dir / spec.raw_name),
        "sheet": res(sheet_path),
        "raw_clean": res(clean_sheet_path),
        "rows": spec.rows,
        "cols": spec.cols,
        "sheet_cell": list(spec.sheet_cell),
        "items": items,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "name": "ui_skins_2026_05_29",
        "style": "warm 1990s Chinese rural pixel-art UI skin",
        "generated_at": "2026-05-29",
    }
    build(BACKPACK, manifest)
    build(SHOP, manifest)
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
