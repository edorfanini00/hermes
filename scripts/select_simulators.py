"""Select real installed simulators, preferring the review iPad model."""
import json
import os
import re
import subprocess

runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
def version(runtime):
    return tuple(int(n) for n in re.findall(r'\d+', runtime))
with open(os.environ['GITHUB_ENV'], 'a') as output:
    for family, variable in [('iPad', 'IPAD_ID'), ('iPhone', 'IPHONE_ID')]:
        candidates = [(runtime, d) for runtime, devices in runtimes.items() if '.iOS-' in runtime
                      for d in devices if d['name'].startswith(family) and d.get('isAvailable')]
        if not candidates:
            raise SystemExit(f'No available {family} simulator')
        runtime, device = max(candidates, key=lambda item: (version(item[0]), 'iPad Air 11-inch (M3)' in item[1]['name']))
        print(f"{family}: {device['name']} ({runtime})")
        output.write(f"{variable}={device['udid']}\n")
