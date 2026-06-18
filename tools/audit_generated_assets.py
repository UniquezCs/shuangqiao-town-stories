#!/usr/bin/env python3
"""Audit generated assets against registry and textual references."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GENERATED_ROOT = ROOT / "assets" / "generated"
ASSETS_JSON = ROOT / "configs" / "assets.json"
IGNORED_NAMES = {".DS_Store"}
IGNORED_SUFFIXES = {".import", ".uid"}
TEXT_SUFFIXES = {".cfg", ".gd", ".godot", ".json", ".md", ".tres", ".tscn"}
RES_PATH_RE = re.compile(r"res://assets/generated/[A-Za-z0-9_./@-]+")


def to_res_path(path: Path) -> str:
	return "res://" + path.relative_to(ROOT).as_posix()


def is_generated_resource(path: Path) -> bool:
	return path.is_file() and path.name not in IGNORED_NAMES and not any(str(path).endswith(suffix) for suffix in IGNORED_SUFFIXES)


def collect_json_paths(value: Any) -> set[str]:
	paths: set[str] = set()
	if isinstance(value, dict):
		for child in value.values():
			paths.update(collect_json_paths(child))
	elif isinstance(value, list):
		for child in value:
			paths.update(collect_json_paths(child))
	elif isinstance(value, str) and value.startswith("res://assets/generated/"):
		paths.add(value)
	return paths


def collect_text_references() -> set[str]:
	references: set[str] = set()
	for path in ROOT.rglob("*"):
		if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
			continue
		if ".git" in path.parts or "assets/generated" in path.as_posix():
			continue
		try:
			text = path.read_text(encoding="utf-8")
		except UnicodeDecodeError:
			continue
		references.update(match.rstrip('",)];') for match in RES_PATH_RE.findall(text))
	return references


def main() -> int:
	parser = argparse.ArgumentParser(description="Audit generated assets and registry references.")
	parser.add_argument("--json", action="store_true", help="Print machine-readable JSON.")
	parser.add_argument("--fail-on-unregistered", action="store_true", help="Exit non-zero when generated resources are missing from configs/assets.json.")
	args = parser.parse_args()

	with ASSETS_JSON.open(encoding="utf-8") as handle:
		registry = json.load(handle)

	generated_resources = {to_res_path(path) for path in GENERATED_ROOT.rglob("*") if is_generated_resource(path)}
	registry_paths = collect_json_paths(registry)
	text_references = collect_text_references()
	registered_files = {path for path in registry_paths if path in generated_resources}
	text_referenced_files = {path for path in text_references if path in generated_resources}
	unregistered = sorted(generated_resources - registered_files)
	unreferenced = sorted(generated_resources - text_referenced_files)
	missing_registry_files = sorted(path for path in registry_paths if path.startswith("res://assets/generated/") and path not in generated_resources and Path(path).suffix)

	report = {
		"generated_resource_count": len(generated_resources),
		"registered_generated_file_count": len(registered_files),
		"text_referenced_generated_file_count": len(text_referenced_files),
		"unregistered_count": len(unregistered),
		"unreferenced_count": len(unreferenced),
		"missing_registry_file_count": len(missing_registry_files),
		"unregistered_sample": unregistered[:20],
		"unreferenced_sample": unreferenced[:20],
		"missing_registry_file_sample": missing_registry_files[:20],
	}

	if args.json:
		print(json.dumps(report, ensure_ascii=False, indent=2))
	else:
		for key, value in report.items():
			if isinstance(value, list):
				print("%s:" % key)
				for item in value:
					print("  - %s" % item)
			else:
				print("%s: %s" % (key, value))

	if args.fail_on_unregistered and unregistered:
		return 1
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
