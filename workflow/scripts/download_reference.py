"""Download reference assets atomically; never distribute them in Git."""
from pathlib import Path
import sys
from urllib.request import urlopen
import shutil

for name in sys.argv[1:]:
    path = Path(name)
    if path.exists() and path.stat().st_size:
        continue
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    url = "https://bonemarrowmap.s3.us-east-2.amazonaws.com/" + path.name
    with urlopen(url, timeout=300) as response, temporary.open("wb") as handle:
        shutil.copyfileobj(response, handle)
    if not temporary.stat().st_size:
        raise ValueError(f"Empty reference download: {url}")
    temporary.replace(path)
