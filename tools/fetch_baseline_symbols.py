"""Fetch Microsoft symbol packages for the AppSource breaking-change baseline.

The product compiles on the BC floor artifact (Application 28.0). The previous
AppSource release can require a newer Application (for example 28.3). This
helper downloads that Application's symbol packages and their Microsoft
dependencies from Microsoft's public MSSymbols NuGet feed into one folder.
prune_self_symbols.py then uses them for the baseline cache only. Nothing is
installed and the compile cache is not touched.

W1 packages only: every Bifrost app builds with country w1.
"""
import argparse
import io
import json
import re
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from appsource_gate import GateError, require
from prune_self_symbols import manifest_identity

FEED = 'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSSymbols/nuget/v3/index.json'
ROOT_PACKAGE = 'Microsoft.Application.symbols'
MAX_PACKAGE_BYTES = 256 * 1024 * 1024
MAX_PACKAGES = 16


def version_key(value):
    return tuple(int(part) for part in value.split('.'))


def parse_range(text):
    """NuGet version range -> (minimum, exclusive maximum or None)."""
    text = text.replace(' ', '')
    exact = re.fullmatch(r'\[([0-9.]+)\]', text)
    if exact:
        return version_key(exact.group(1)), None, version_key(exact.group(1))
    bounded = re.fullmatch(r'\[([0-9.]+),([0-9.]*)\)', text)
    if bounded:
        low, high = bounded.groups()
        return version_key(low), version_key(high) if high else None, None
    require(re.fullmatch(r'[0-9.]+', text) is not None, f'Unsupported NuGet version range {text}')
    return version_key(text), None, None


def select_version(versions, version_range):
    low, high, exact = version_range
    candidates = []
    for version in versions:
        if not re.fullmatch(r'[0-9]+(\.[0-9]+){1,3}', version):
            continue  # prerelease or malformed
        key = version_key(version)
        if exact is not None and key != exact:
            continue
        if key < low or (high is not None and key >= high):
            continue
        candidates.append((key, version))
    require(candidates, f'No symbol package version matches {version_range}')
    return min(candidates)[1]  # earliest matching build, closest to what the baseline used


def fetch(url, attempts=3, limit=MAX_PACKAGE_BYTES):
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                data = response.read(limit + 1)
            require(len(data) <= limit, 'Symbol download too large')
            return data
        except urllib.error.HTTPError as error:
            if error.code < 500 or attempt == attempts:
                raise GateError(f'Symbol feed request failed ({error.code}): {url}') from error
        except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
            if attempt == attempts:
                raise GateError(f'Symbol feed unreachable: {error}') from error
        print(f'Symbol feed attempt {attempt} failed; retrying', file=sys.stderr)
        time.sleep(10 * attempt)
    raise GateError('unreachable')


def base_address(feed):
    index = json.loads(fetch(feed, limit=4 * 1024 * 1024))
    for resource in index.get('resources', []):
        if str(resource.get('@type', '')).startswith('PackageBaseAddress/3.0.0'):
            return resource['@id'].rstrip('/') + '/'
    raise GateError('Symbol feed has no PackageBaseAddress')


def download(required, folder, feed=FEED, fetcher=None):
    fetcher = fetcher or fetch
    require(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+', required) is not None, 'Invalid Application requirement')
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    require(not folder.is_symlink(), 'Linked symbol folder refused')
    base = base_address(feed) if fetcher is fetch else feed
    queue = [(ROOT_PACKAGE, (version_key(required), None, None))]
    done, written = set(), []
    while queue:
        package, version_range = queue.pop(0)
        lower = package.lower()
        if lower in done or lower.startswith('microsoft.platform'):
            continue
        require(lower.startswith('microsoft.'), f'Non-Microsoft dependency {package}')
        require(len(done) < MAX_PACKAGES, 'Symbol package bound exceeded')
        done.add(lower)
        versions = json.loads(fetcher(f'{base}{lower}/index.json'))['versions']
        version = select_version(versions, version_range)
        archive = zipfile.ZipFile(io.BytesIO(fetcher(f'{base}{lower}/{version}/{lower}.{version}.nupkg')))
        nuspecs = [name for name in archive.namelist() if name.lower().endswith('.nuspec') and '/' not in name]
        require(len(nuspecs) == 1, f'Ambiguous nuspec in {package}')
        spec = ET.fromstring(archive.read(nuspecs[0]))
        for dependency in spec.iter():
            if dependency.tag.endswith('}dependency') or dependency.tag == 'dependency':
                queue.append((dependency.attrib['id'], parse_range(dependency.attrib.get('version', '0.0'))))
        apps = [name for name in archive.namelist() if name.lower().endswith('.app') and '/' not in name]
        require(len(apps) == 1, f'Expected one .app in {package} {version}')
        target = folder / Path(apps[0]).name
        target.write_bytes(archive.read(apps[0]))
        identity = manifest_identity(target)
        if identity['publisher'] != 'Microsoft':
            target.unlink()
            raise GateError(f'{package} is not a Microsoft package')
        written.append({'package': package, 'version': version, 'file': target.name, 'name': identity['name']})
    require(any(item['name'] == 'Application' for item in written), 'Application symbols missing')
    return written


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--required', required=True)
    parser.add_argument('--folder', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps({'baselineSymbols': download(args.required, args.folder)}))
    except (GateError, OSError, ValueError, KeyError, zipfile.BadZipFile, ET.ParseError) as error:
        parser.exit(1, f'Baseline symbol download failed: {error}\n')
