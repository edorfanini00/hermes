"""Select installed runtimes and reproduce Apple's 11-inch iPad layout."""
import json
import os
import re
import subprocess


def simctl(*arguments):
    return subprocess.check_output(['xcrun', 'simctl', *arguments], text=True)


def version(runtime):
    return tuple(int(n) for n in re.findall(r'\d+', runtime))


runtimes = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
available = [runtime for runtime in runtimes if '.iOS-' in runtime]
if not available:
    raise SystemExit('No installed iOS simulator runtime')
latest = max(available, key=version)
types = json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes']
preferred_ipad = next((t for t in types if t['name'] == 'iPad Air 11-inch (M3)'), None)
if preferred_ipad:
    existing = next((d for d in runtimes[latest] if d.get('deviceTypeIdentifier') == preferred_ipad['identifier'] and d.get('isAvailable')), None)
    if existing is None:
        udid = simctl('create', 'App Review iPad Air 11-inch M3', preferred_ipad['identifier'], latest).strip()
        runtimes[latest].append({'name': 'iPad Air 11-inch (M3)', 'udid': udid, 'isAvailable': True})

with open(os.environ['GITHUB_ENV'], 'a') as output:
    for family, variable in [('iPad', 'IPAD_ID'), ('iPhone', 'IPHONE_ID')]:
        candidates = [d for d in runtimes[latest] if (d['name'].startswith(family) or (family == 'iPad' and 'App Review iPad' in d['name'])) and d.get('isAvailable')]
        if not candidates:
            raise SystemExit(f'No available {family} simulator for {latest}')
        device = max(candidates, key=lambda d: ('iPad Air 11-inch' in d['name'], 'M3' in d['name']))
        print(f"{family}: {device['name']} ({latest})")
        output.write(f"{variable}={device['udid']}\n")
