#!/usr/bin/env python3
"""Normalize generated art metadata and registry paths.

This script only derives small variants from existing art and updates JSON
registries. It does not generate new source artwork.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSISTANT_DIR = ROOT / "assets/generated/assistant_art_2026_05_29"
UI_SKIN_DIR = ROOT / "assets/generated/ui_skins_2026_05_29"
CONFIGS = ROOT / "configs"


def res(path: Path) -> str:
    return "res://" + str(path.relative_to(ROOT))


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def normalize_png(src: Path, out: Path, size: tuple[int, int] = (32, 32), fit: float = 0.88) -> None:
    img = Image.open(src).convert("RGBA")
    bbox = img.getbbox()
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if bbox is None:
        canvas.save(out)
        return
    img = img.crop(bbox)
    scale = min((size[0] * fit) / img.width, (size[1] * fit) / img.height)
    new_size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    img = img.resize(new_size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(img, ((size[0] - img.width) // 2, (size[1] - img.height) // 2))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)


def actual_size(path: str) -> list[int]:
    local = ROOT / path.replace("res://", "")
    if local.suffix.lower() == ".png" and local.exists():
        img = Image.open(local)
        return [img.width, img.height]
    return []


def enrich_item(
    *,
    asset_id: str,
    asset_type: str,
    path: str,
    size: list[int],
    usage: list[str],
    tags: list[str],
    anchor: str = "center",
    collision: str = "none",
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": asset_id,
        "type": asset_type,
        "path": path,
        "size": size,
        "anchor": anchor,
        "collision": collision,
        "usage": usage,
        "tags": tags,
    }
    if extra:
        item.update(extra)
    return item


def build_32_variants() -> dict[str, str]:
    variants: dict[str, str] = {}

    for folder in ["crop_icons", "ui_icons"]:
        items_dir = ASSISTANT_DIR / folder / "items"
        for src in sorted(items_dir.glob("*.png")):
            if src.stem.endswith("_32"):
                continue
            out = src.with_name(f"{src.stem}_32.png")
            normalize_png(src, out, (32, 32), 0.9)
            variants[f"{folder}.{src.stem}"] = res(out)

    fertilizer_src = ROOT / "assets/generated/props/street_stall_props_v2_cutouts/16_seed_bag_large.png"
    fertilizer_out = ASSISTANT_DIR / "ui_icons/items/fertilizer_placeholder_32.png"
    normalize_png(fertilizer_src, fertilizer_out, (32, 32), 0.86)
    variants["ui_icons.fertilizer_placeholder"] = res(fertilizer_out)
    return variants


def enrich_assistant_manifest(variants: dict[str, str]) -> None:
    path = ASSISTANT_DIR / "manifest.json"
    data = read_json(path)
    data["schema_version"] = 2
    data["id"] = "pack.assistant_art_2026_05_29"
    data["type"] = "generated_art_pack"
    data["anchor_default"] = "center"
    data["collision_default"] = "none"

    pack_specs = {
        "farm_plots": ("farm_state", [64, 64], ["farm_plot_visual"], ["farm", "plot", "tile"]),
        "crop_icons": ("item_icon", [48, 48], ["inventory_icon", "shop_icon"], ["crop", "inventory"]),
        "ui_icons": ("ui_icon", [48, 48], ["hud_icon", "ui_icon"], ["ui"]),
        "town_rural_props": ("prop", [96, 96], ["scene_prop", "decoration"], ["prop", "town", "rural"]),
    }

    for pack_key, (asset_type, default_size, usage, tags) in pack_specs.items():
        pack = data.get(pack_key, {})
        items = pack.get("items", {})
        enriched: dict[str, Any] = {}
        for name, value in items.items():
            item_path = value if isinstance(value, str) else value.get("path", "")
            item_size = actual_size(item_path) or default_size
            extra: dict[str, Any] = {}
            variant_key = f"{pack_key}.{name}"
            if variant_key in variants:
                extra["variants"] = {"32": variants[variant_key]}
            enriched[name] = enrich_item(
                asset_id=f"{pack_key}.{name}",
                asset_type=asset_type,
                path=item_path,
                size=item_size,
                usage=usage,
                tags=tags + [name],
                extra=extra,
            )
        pack["items"] = enriched
        data[pack_key] = pack

    write_json(path, data)


def enrich_ui_skin_manifest() -> None:
    path = UI_SKIN_DIR / "manifest.json"
    data = read_json(path)
    data["schema_version"] = 2
    data["id"] = "pack.ui_skins_2026_05_29"
    data["type"] = "ui_skin_pack"
    data["anchor_default"] = "center"
    data["collision_default"] = "none"

    for pack_key in ["backpack", "shop"]:
        pack = data.get(pack_key, {})
        enriched: dict[str, Any] = {}
        for name, value in pack.get("items", {}).items():
            item_path = value["path"]
            enriched[name] = enrich_item(
                asset_id=f"ui_skin.{pack_key}.{name}",
                asset_type="ui_component",
                path=item_path,
                size=value["size"],
                usage=[f"{pack_key}_ui"],
                tags=["ui", pack_key, name],
            )
        pack["items"] = enriched
        data[pack_key] = pack

    write_json(path, data)


def update_items_config(variants: dict[str, str]) -> None:
    path = CONFIGS / "items.json"
    data = read_json(path)
    critical_dir = ROOT / "assets/generated/critical_icons_2026_05_29/items"

    replacements = {
        "apple": variants.get("crop_icons.apple"),
        "apple_seed": "res://assets/generated/sprites/ui/icons/apple_seed_packet_32.png",
        "cabbage": variants.get("crop_icons.cabbage"),
        "cucumber": variants.get("crop_icons.cucumber"),
        "tomato": variants.get("crop_icons.tomato"),
        "potato": variants.get("crop_icons.potato"),
        "pear": res(critical_dir / "pear_32.png") if (critical_dir / "pear_32.png").exists() else data.get("pear", {}).get("icon", ""),
        "cabbage_seed": res(critical_dir / "cabbage_seed_packet_32.png") if (critical_dir / "cabbage_seed_packet_32.png").exists() else data.get("cabbage_seed", {}).get("icon", ""),
        "cucumber_seed": res(critical_dir / "cucumber_seed_packet_32.png") if (critical_dir / "cucumber_seed_packet_32.png").exists() else data.get("cucumber_seed", {}).get("icon", ""),
        "tomato_seed": res(critical_dir / "tomato_seed_packet_32.png") if (critical_dir / "tomato_seed_packet_32.png").exists() else data.get("tomato_seed", {}).get("icon", ""),
        "pear_seed": res(critical_dir / "pear_seed_packet_32.png") if (critical_dir / "pear_seed_packet_32.png").exists() else data.get("pear_seed", {}).get("icon", ""),
        "potato_seed": res(critical_dir / "potato_seed_packet_32.png") if (critical_dir / "potato_seed_packet_32.png").exists() else data.get("potato_seed", {}).get("icon", ""),
        "fertilizer": res(critical_dir / "fertilizer_bag_32.png") if (critical_dir / "fertilizer_bag_32.png").exists() else variants.get("ui_icons.fertilizer_placeholder"),
    }
    for item_id, icon_path in replacements.items():
        if icon_path and item_id in data:
            data[item_id]["icon"] = icon_path

    write_json(path, data)


def update_assets_registry(variants: dict[str, str]) -> None:
    path = CONFIGS / "assets.json"
    data = read_json(path)
    data["updated_at"] = "2026-05-29"
    critical_dir = ROOT / "assets/generated/critical_icons_2026_05_29/items"
    critical_manifest = ROOT / "assets/generated/critical_icons_2026_05_29/manifest.json"
    if critical_manifest.exists():
        data.setdefault("packs", {})["critical_icons_2026_05_29"] = {
            "id": "pack.critical_icons_2026_05_29",
            "type": "icon_pack",
            "status": "available",
            "path": "res://assets/generated/sprites/items",
            "notes": "Pear, per-crop seed packets, fertilizer, sickle, warning, and fine icons normalized to 32x32.",
        }

    items = data["items"]
    implemented_crop_paths = {
        "item.apple": variants["crop_icons.apple"],
        "item.cabbage": variants["crop_icons.cabbage"],
        "item.cucumber": variants["crop_icons.cucumber"],
        "item.tomato": variants["crop_icons.tomato"],
        "item.potato": variants["crop_icons.potato"],
    }
    for asset_id, icon_path in implemented_crop_paths.items():
        if asset_id in items:
            items[asset_id]["status"] = "implemented"
            items[asset_id]["path"] = icon_path
            items[asset_id].pop("available_path", None)
            items[asset_id]["size"] = [32, 32]
            items[asset_id].pop("required_size", None)
            items[asset_id]["anchor"] = "center"
            items[asset_id]["collision"] = "none"
            items[asset_id].setdefault("tags", ["item", "crop", asset_id.split(".")[-1]])

    if "item.apple_seed" in items:
        items["item.apple_seed"]["status"] = "implemented"
        items["item.apple_seed"]["path"] = "res://assets/generated/sprites/ui/icons/apple_seed_packet_32.png"
        items["item.apple_seed"].pop("available_path", None)
        items["item.apple_seed"]["anchor"] = "center"
        items["item.apple_seed"]["collision"] = "none"
        items["item.apple_seed"].setdefault("tags", ["item", "seed", "apple"])

    if "item.fertilizer" in items:
        fertilizer_path = (
            res(critical_dir / "fertilizer_bag_32.png")
            if (critical_dir / "fertilizer_bag_32.png").exists()
            else variants["ui_icons.fertilizer_placeholder"]
        )
        items["item.fertilizer"]["path"] = fertilizer_path
        items["item.fertilizer"]["size"] = [32, 32]
        items["item.fertilizer"].pop("required_size", None)
        items["item.fertilizer"]["anchor"] = "center"
        items["item.fertilizer"]["collision"] = "none"
        if critical_manifest.exists():
            items["item.fertilizer"]["status"] = "implemented"
            items["item.fertilizer"].pop("generation_need", None)
            items["item.fertilizer"].pop("notes", None)
            items["item.fertilizer"]["tags"] = ["item", "fertilizer"]
        else:
            items["item.fertilizer"]["notes"] = "Normalized 32x32 placeholder derived from existing seed-bag art; still needs dedicated fertilizer artwork."
            items["item.fertilizer"].setdefault("tags", ["item", "placeholder", "fertilizer"])

    tools = data["tools"]
    tool_paths = {
        "tool.hoe": variants["ui_icons.hoe"],
        "tool.water": variants["ui_icons.watering_can"],
    }
    for asset_id, icon_path in tool_paths.items():
        if asset_id in tools:
            tools[asset_id]["status"] = "available"
            tools[asset_id]["path"] = icon_path
            tools[asset_id].pop("available_path", None)
            tools[asset_id]["size"] = [32, 32]
            tools[asset_id].pop("required_size", None)
            tools[asset_id]["anchor"] = "center"
            tools[asset_id]["collision"] = "none"
            tools[asset_id].setdefault("tags", ["tool", asset_id.split(".")[-1]])

    for section_name in ["farm_plots", "stalls", "locations", "ui", "town_props", "characters", "tilesets"]:
        for asset in data.get(section_name, {}).values():
            if isinstance(asset, dict):
                asset.setdefault("anchor", "center")
                asset.setdefault("collision", "none")
                asset.setdefault("tags", [section_name])

    ui = data["ui"]
    if "ui.backpack_panel" in ui:
        ui["ui.backpack_panel"]["available_components"] = {
            "panel_frame": "res://assets/generated/sprites/ui/backpack/panel_frame.png",
            "slot_empty": "res://assets/generated/sprites/ui/backpack/slot_empty.png",
            "slot_highlighted": "res://assets/generated/sprites/ui/backpack/slot_highlighted.png",
            "slot_locked": "res://assets/generated/sprites/ui/backpack/slot_locked.png",
            "quantity_badge": "res://assets/generated/sprites/ui/backpack/quantity_badge.png",
        }
    if "ui.shop_panel" in ui:
        ui["ui.shop_panel"]["available_components"] = {
            "panel_frame": "res://assets/generated/sprites/ui/shop/panel_frame.png",
            "goods_shelf_card": "res://assets/generated/sprites/ui/shop/goods_shelf_card.png",
            "buy_button": "res://assets/generated/sprites/ui/shop/buy_button.png",
            "disabled_buy_button": "res://assets/generated/sprites/ui/shop/disabled_buy_button.png",
            "price_tag_badge": "res://assets/generated/sprites/ui/shop/price_tag_badge.png",
        }

    write_json(path, data)


def main() -> None:
    variants = build_32_variants()
    enrich_assistant_manifest(variants)
    enrich_ui_skin_manifest()
    update_items_config(variants)
    update_assets_registry(variants)


if __name__ == "__main__":
    main()
