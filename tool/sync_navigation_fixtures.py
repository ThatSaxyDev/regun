#!/usr/bin/env python3
"""Copy the canonical navigation fixture into a sibling server checkout."""
import argparse
import hashlib
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('--server', type=Path, default=Path(__file__).resolve().parents[2] / 'regun-server')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1] / 'test/fixtures/minion-navigation-v1.json'
target = args.server / 'shared/minion-navigation-v1.json'
if not target.parent.is_dir():
    parser.error('Server shared/ directory is missing; pass --server explicitly.')
target.write_bytes(source.read_bytes())
print(f'{hashlib.sha256(source.read_bytes()).hexdigest()}  minion-navigation-v1.json')
