"""Use the same narrow pinned-engine startup policy as the Node QA helper."""
import json, os, re
from pathlib import Path

POLICY = json.loads(Path(__file__).with_name('godot-log-policy.json').read_text())

def godot_log(raw, platform=None):
    text = raw.replace('\r\n', '\n')
    platform = ('win32' if os.name == 'nt' else os.name) if platform is None else platform
    fallback = (platform == 'win32'
                and len(re.findall(POLICY['storeError'], text, re.M)) == 1
                and re.search(POLICY['banner'], text, re.M) is not None
                and len(re.findall(POLICY['fallback'], text, re.M)) == 1)
    if fallback:
        text = re.sub(POLICY['storeError'], '', text, count=1, flags=re.M)
    return {'failed': re.search(POLICY['bad'], text, re.M) is not None,
            'builtinFallback': bool(fallback)}
