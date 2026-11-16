#!/usr/bin/env python3
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
files=sorted(str(p.relative_to(root)) for p in (root/'test').rglob('*_test.dart') if not p.name.endswith('_integration_test.dart') or p.name=='trip_photo_likes_integration_test.dart')
raise SystemExit(subprocess.call(['flutter','test','--reporter','expanded',*files],cwd=root))
