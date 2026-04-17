#!/usr/bin/env python3
"""Render the supported image matrix from the shipped TSV manifest."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MATRIX_FILE = ROOT / "files/base/runtime/usr/share/myos/image-matrix.tsv"
FIELDS = ["job", "role", "tier", "family", "distro", "hardware", "image", "recipe"]
ALLOWED_JOBS = {
    "server-images",
    "workstation-core-images",
    "workstation-full-images",
    "console-images",
}
ALLOWED_ROLES = {"workstation", "server", "console"}
ALLOWED_TIERS = {"core", "full"}
ALLOWED_FAMILIES = {"GNOME", "COSMIC", "-", "preview"}
ALLOWED_HARDWARE = {"default", "nvidia-open", "nvidia-legacy"}
EXPECTED_FEDORA43 = {
    "recipes/images/workstation/gnome/fedora43/core.yml",
    "recipes/images/workstation/gnome/fedora43/core-nvidia-open.yml",
    "recipes/images/workstation/cosmic/fedora43/core.yml",
    "recipes/images/workstation/cosmic/fedora43/core-nvidia-open.yml",
}


def die(message: str) -> None:
    raise SystemExit(message)


def recipe_ref(recipe: str) -> str:
    if not recipe.startswith("recipes/"):
        die(f"recipe path must start with 'recipes/': {recipe}")
    return "/" + recipe.removeprefix("recipes/")


def display_role(role: str) -> str:
    return role[:1].upper() + role[1:]


def load_rows() -> list[dict[str, str]]:
    if not MATRIX_FILE.is_file():
        die(f"matrix file not found: {MATRIX_FILE}")

    with MATRIX_FILE.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames != FIELDS:
            die("image matrix header must be exactly: " + "\t".join(FIELDS))

        rows: list[dict[str, str]] = []
        seen_images: set[str] = set()
        seen_recipes: set[str] = set()

        for line_number, raw_row in enumerate(reader, start=2):
            row = {field: (raw_row.get(field) or "").strip() for field in FIELDS}
            missing = [field for field, value in row.items() if not value]
            if missing:
                die(
                    f"{MATRIX_FILE}:{line_number}: missing required fields: "
                    + ", ".join(missing)
                )

            if row["job"] not in ALLOWED_JOBS:
                die(f"{MATRIX_FILE}:{line_number}: unsupported job: {row['job']}")
            if row["role"] not in ALLOWED_ROLES:
                die(f"{MATRIX_FILE}:{line_number}: unsupported role: {row['role']}")
            if row["tier"] not in ALLOWED_TIERS:
                die(f"{MATRIX_FILE}:{line_number}: unsupported tier: {row['tier']}")
            if row["family"] not in ALLOWED_FAMILIES:
                die(f"{MATRIX_FILE}:{line_number}: unsupported family: {row['family']}")
            if row["hardware"] not in ALLOWED_HARDWARE:
                die(
                    f"{MATRIX_FILE}:{line_number}: unsupported hardware lane: "
                    f"{row['hardware']}"
                )
            if not row["recipe"].startswith("recipes/images/") or not row["recipe"].endswith(".yml"):
                die(f"{MATRIX_FILE}:{line_number}: invalid recipe path: {row['recipe']}")
            if row["image"] in seen_images:
                die(f"{MATRIX_FILE}:{line_number}: duplicate image tag: {row['image']}")
            if row["recipe"] in seen_recipes:
                die(f"{MATRIX_FILE}:{line_number}: duplicate recipe path: {row['recipe']}")

            if row["role"] == "server":
                if row["tier"] != "full" or row["family"] != "-":
                    die(f"{MATRIX_FILE}:{line_number}: server rows must be full tier with '-' family")
            elif row["role"] == "console":
                if row["tier"] != "core" or row["family"] != "preview":
                    die(f"{MATRIX_FILE}:{line_number}: console rows must be core tier with preview family")
            elif row["family"] not in {"GNOME", "COSMIC"}:
                die(f"{MATRIX_FILE}:{line_number}: workstation rows must use GNOME or COSMIC")

            if row["distro"] == "fedora43":
                if row["role"] != "workstation" or row["tier"] != "core":
                    die(f"{MATRIX_FILE}:{line_number}: fedora43 must stay workstation core only")
                if row["family"] not in {"GNOME", "COSMIC"}:
                    die(f"{MATRIX_FILE}:{line_number}: fedora43 must stay limited to GNOME/COSMIC")
                if row["hardware"] not in {"default", "nvidia-open"}:
                    die(f"{MATRIX_FILE}:{line_number}: fedora43 must stay limited to default/nvidia-open")

            seen_images.add(row["image"])
            seen_recipes.add(row["recipe"])
            rows.append(row)

    fedora43_recipes = {row["recipe"] for row in rows if row["distro"] == "fedora43"}
    if fedora43_recipes != EXPECTED_FEDORA43:
        missing = sorted(EXPECTED_FEDORA43 - fedora43_recipes)
        extra = sorted(fedora43_recipes - EXPECTED_FEDORA43)
        details: list[str] = []
        if missing:
            details.append("missing: " + ", ".join(missing))
        if extra:
            details.append("extra: " + ", ".join(extra))
        die(
            "Fedora 43 must stay limited to four workstation-core recipes"
            + (" (" + "; ".join(details) + ")" if details else "")
        )

    return rows


def filter_rows(rows: list[dict[str, str]], args: argparse.Namespace) -> list[dict[str, str]]:
    for field in ("job", "role", "tier", "family", "distro", "hardware"):
        value = getattr(args, field, None)
        if value:
            rows = [row for row in rows if row[field] == value]
    return rows


def cmd_recipes(args: argparse.Namespace) -> int:
    for row in filter_rows(load_rows(), args):
        print(row["recipe"])
    return 0


def cmd_gha(args: argparse.Namespace) -> int:
    rows = [row for row in load_rows() if row["job"] == args.job]
    payload = [{"name": row["image"], "recipe": recipe_ref(row["recipe"])} for row in rows]
    json.dump(payload, sys.stdout, separators=(",", ":"))
    print()
    return 0


def cmd_rebase(_: argparse.Namespace) -> int:
    for row in load_rows():
        print(
            f"{display_role(row['role'])} | {row['tier']} | {row['family']} | "
            f"{row['distro']} | {row['hardware']} | {row['image']}:latest"
        )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    recipes = subparsers.add_parser("recipes", help="print supported recipe paths")
    recipes.add_argument("--job")
    recipes.add_argument("--role")
    recipes.add_argument("--tier")
    recipes.add_argument("--family")
    recipes.add_argument("--distro")
    recipes.add_argument("--hardware")
    recipes.set_defaults(func=cmd_recipes)

    gha = subparsers.add_parser("gha", help="emit a GitHub Actions matrix JSON array")
    gha.add_argument("job", choices=sorted(ALLOWED_JOBS))
    gha.set_defaults(func=cmd_gha)

    rebase = subparsers.add_parser("rebase", help="emit myos rebase picker rows")
    rebase.set_defaults(func=cmd_rebase)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
