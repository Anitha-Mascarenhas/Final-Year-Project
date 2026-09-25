#!/usr/bin/env python3
"""Standalone patch: make the frontal1-finetune experiment report writer resilient to manifest shape differences.

It rewrites the smoke/fabricated run_experiment.py so that:
- split lookups always go through the ds dict (already validated by build_dataset_items)
- report assembly never assumes manifest["train"]["n"] etc.
- subgroup lookups reuse the already-parsed items from ds["test"] so the writer cannot crash on missing subgroups
"""

from pathlib import Path
import re

path = Path("experiments/image_model_frontal1_finetuned/run_experiment.py")
src = path.read_text(encoding="utf-8")


def replace_or_fail(pattern, replacement, *, count=1):
    global src
    new, n = re.subn(pattern, replacement, src, count=count)
    if n != count:
        raise SystemExit(f"expected {count} replacement(s) for pattern, got {n}")
    src = new


# 1) Ensure build_dataset_items reads the manifest robustly.
#    Prefer splits-only access, but also tolerate a raw manifest shape that includes 'total'
#    alongside 'splits' (so we never crash later on manifest["train"]["n"]).
replace_or_fail(
    r'd = raw\.get\("splits", raw\)\n\s*for k in \("train", "validation", "test"\):\n\s*if k not in d:\n\s*raise AssertionError\(\(.*?split key.*?\), k, list\(d\.keys\(\)\)\)\n',
    'splits = raw.get("splits", raw)\n'
    'for k in ("train", "validation", "test"):\n'
    '    if k not in splits:\n'
    '        raise AssertionError(("manifest missing split key", k, list(raw.keys())))\n\n'
    'd = splits\n',
    count=1,
)

# 2) Replace direct manifest["train"]["n"] style lookups in the report assembly with ds access.
report_block_pattern = (
    r'        "splits": \{\n'
    r'(?:            "train": \{[^}]*?\},\n)*'
    r'(?:            "validation": \{[^}]*?\},\n)*'
    r'(?:            "test": \{[^}]*?\},\n)*'
    r'        \},'
)
m = re.search(report_block_pattern, src, flags=re.DOTALL)
if not m:
    raise SystemExit("could not locate report splits block to rewrite")

report_block = m.group(0)


def normalize_split_block(text):
    def fix_one_block(block_text):
        block_text = re.sub(
            r'"children":\s*manifest\["train"\]\["n"\]',
            'ds["train"]["n"]', block_text,
        )
        block_text = re.sub(
            r'"children_by_class":\s*manifest\["train"\]\["by_label"\]',
            'ds["train"]["by_label"]', block_text,
        )
        block_text = re.sub(
            r'"children_by_subgroup":\s*manifest\["train"\]\["by_subgroup"\]',
            'ds["train"]["by_subgroup"]', block_text,
        )
        block_text = re.sub(
            r'"images":\s*manifest\["train"\]\["n"\]',
            'ds["train"]["n"]', block_text,
        )
        block_text = re.sub(
            r'"children":\s*manifest\["validation"\]\["n"\]',
            'ds["validation"]["n"]', block_text,
        )
        block_text = re.sub(
            r'"children_by_class":\s*manifest\["validation"\]\["by_label"\]',
            'ds["validation"]["by_label"]', block_text,
        )
        block_text = re.sub(
            r'"children_by_subgroup":\s*manifest\["validation"\]\["by_subgroup"\]',
            'ds["validation"]["by_subgroup"]', block_text,
        )
        block_text = re.sub(
            r'"images":\s*manifest\["validation"\]\["n"\]',
            'ds["validation"]["n"]', block_text,
        )
        block_text = re.sub(
            r'"children":\s*manifest\["test"\]\["n"\]',
            'ds["test"]["n"]', block_text,
        )
        block_text = re.sub(
            r'"children_by_class":\s*manifest\["test"\]\["by_label"\]',
            'ds["test"]["by_label"]', block_text,
        )
        block_text = re.sub(
            r'"children_by_subgroup":\s*manifest\["test"\]\["by_subgroup"\]',
            'ds["test"]["by_subgroup"]', block_text,
        )
        block_text = re.sub(
            r'"images":\s*manifest\["test"\]\["n"\]',
            'ds["test"]["n"]', block_text,
        )
        return block_text

    parts = re.split(r'(            "(?:train|validation|test)": \{|\n        \},\n)', text)
    out = []
    current_block = None
    for part in parts:
        if part.strip().startswith('"train":') or part.strip().startswith('"validation":') or part.strip().startswith('"test":'):
            if current_block is not None:
                out.append(fix_one_block(current_block))
            current_block = part
        elif part == '\n        },\n':
            if current_block is not None:
                out.append(fix_one_block(current_block))
                out.append(part)
                current_block = None
            else:
                out.append(part)
        else:
            out.append(part)
    if current_block is not None:
        out.append(fix_one_block(current_block))
    return "".join(out)


src = src[: m.start()] + normalize_split_block(report_block) + src[m.end() :]

path.write_text(src, encoding="utf-8")
print("rewrote report-assembly manifest lookups to use ds[...] keys.")
