from pathlib import Path
from datetime import datetime
import re

folder = Path("/tmp/ble.dump.0/raw_csv")          # directory to scan
pattern = re.compile(r"_(\d{8}_\d{6})\.csv$")     # captures 20250412_214844

earliest_file   = None
earliest_dt     = None

for f in folder.glob("*.csv"):                    # or **/*.csv for sub‑dirs
    m = pattern.search(f.name)
    if not m:
        continue                                  # skip non‑matching files

    ts = datetime.strptime(m.group(1), "%Y%m%d_%H%M%S")

    if earliest_dt is None or ts < earliest_dt:
        earliest_dt  = ts
        earliest_file = f

# `earliest_file` is a pathlib.Path (or None if nothing matched)
print("Earliest file:", earliest_file)