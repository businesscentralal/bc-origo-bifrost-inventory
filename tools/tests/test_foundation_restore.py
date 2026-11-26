"""TestApps filename collision restore. Synthetic packages, not artifact certification."""
import base64
import copy
import http.server
import io
import json
import threading
import struct
import sys
import tempfile
import unittest
import uuid
import zipfile
from pathlib import Path
from unittest.mock import patch
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).parents[1]))
import stage_foundation_inputs as S
from test_symbol_policy import fixture
import prune_self_symbols as P
import fetch_baseline_symbols as F


def with_friend(path):
    data = path.read_bytes()
    with zipfile.ZipFile(io.BytesIO(data[40:])) as archive:
        entries = [(name, archive.read(name)) for name in archive.namelist()]
    namespace = "{http://schemas.microsoft.com/navx/2015/manifest}"
    updated = []
    for name, content in entries:
        if name == "NavxManifest.xml":
            root = ET.fromstring(content)
            parent = root.find(namespace + "InternalsVisibleTo")
            ET.SubElement(parent, namespace + "Module", {
                "Id": S.TEST_FRIEND["id"], "Publisher": S.TEST_FRIEND["publisher"], "Name": S.TEST_FRIEND["name"]})
            content = ET.tostring(root)
        updated.append((name, content))
    payload = io.BytesIO()
    with zipfile.ZipFile(payload, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in updated:
            archive.writestr(name, content)
    header = bytearray(data[:40])
    struct.pack_into("<Q", header, 28, len(payload.getvalue()))
    path.write_bytes(bytes(header) + payload.getvalue())


def archive_of(path, destination):
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(path, path.name)
    return destination


class WorkflowToken(unittest.TestCase):
    def test_algo_secret_json_is_base64_decoded(self):
        encoded = base64.b64encode(b"ghp_exampletokenvalue000").decode("ascii")
        with patch.dict("os.environ", {"Secrets": json.dumps({"ghTokenWorkflow": encoded})}, clear=False):
            self.assertEqual("ghp_exampletokenvalue000", S.workflow_token())


class ArtifactDownload(unittest.TestCase):
    def test_redirect_does_not_forward_the_token(self):
        seen = {}

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                seen.setdefault(self.path, []).append(self.headers.get("Authorization"))
                if self.path == "/zip":
                    self.send_response(302)
                    location = "http://127.0.0.1:%d/file" % self.server.server_address[1]
                    self.send_header("Location", location)
                    self.end_headers()
                    return
                if self.headers.get("Authorization"):
                    self.send_response(401)
                    self.end_headers()
                    return
                body = b"PK\x03\x04ok"
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, fmt, *args):
                return

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        destination = Path(tempfile.mkdtemp()) / "artifact.bin"
        try:
            S._download_url("http://127.0.0.1:%d/zip" % server.server_address[1],
                            "secret-token-value-0000", destination)
            self.assertEqual(b"PK\x03\x04ok", destination.read_bytes())
            self.assertEqual("Bearer secret-token-value-0000", seen["/zip"][0])
            self.assertIsNone(seen["/file"][0])
        finally:
            server.shutdown()
            server.server_close()

    def test_dropped_connection_is_retried(self):
        calls = {"n": 0}

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                calls["n"] += 1
                if calls["n"] == 1:
                    self.close_connection = True
                    return
                body = b"PK\x03\x04ok"
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, fmt, *args):
                return

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        destination = Path(tempfile.mkdtemp()) / "artifact.bin"
        try:
            with patch.object(S.time, "sleep"):
                S._download_url("http://127.0.0.1:%d/file" % server.server_address[1],
                                "secret-token-value-0000", destination)
            self.assertEqual(b"PK\x03\x04ok", destination.read_bytes())
            self.assertGreaterEqual(calls["n"], 2)
        finally:
            server.shutdown()
            server.server_close()


class FoundationRestore(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dependencies = self.root / ".dependencies"
        self.dependencies.mkdir()
        self.identity = dict(S.PROFILES["release741"]["identity"])
        self.collision = self.dependencies / "Origo_Bifrost Foundation_28.0.13.741.app"
        fixture(self.collision, self.identity)
        with_friend(self.collision)
        self.approved_source = self.root / "approved.app"
        fixture(self.approved_source, self.identity)
        self.archive = archive_of(self.approved_source, self.root / "apps.zip")
        self.config = copy.deepcopy(S.PROFILES["release741"])
        self.config["pin"] = S.file_hash(self.approved_source)
        self.config["testPin"] = S.file_hash(self.collision)
        self.config["source"] = ""
        self.config["buildUrl"] = ""
        self.config["artifacts"] = dict(self.config["artifacts"])
        self.config["artifacts"]["Apps"] = (self.config["artifacts"]["Apps"][0], S.file_hash(self.archive))
        self.calls = 0

    def fetch(self, destination):
        self.calls += 1
        destination.write_bytes(self.archive.read_bytes())
        return destination

    def restore(self):
        with patch.dict(S.PROFILES, {"release741": self.config}):
            return S.restore_overwritten_foundation(self.root, self.fetch)

    def test_testapps_collision_is_replaced_and_other_files_stay(self):
        other = self.dependencies / "Other.app"
        other.write_bytes(b"leave-me")
        result = self.restore()
        self.assertEqual("restored", result["action"])
        self.assertEqual(self.config["pin"], S.file_hash(self.collision))
        self.assertEqual([], S.package_info(self.collision)["friends"])
        self.assertEqual(b"leave-me", other.read_bytes())
        self.assertEqual(1, self.calls)

    def test_symbol_folder_outside_the_standard_cache_is_restored(self):
        self.collision.unlink()
        symbols = self.root / "compiler-symbols"
        symbols.mkdir()
        external = symbols / "Origo_Bifrost Foundation_28.0.13.741.app"
        fixture(external, self.identity)
        with_friend(external)
        self.config["testPin"] = S.file_hash(external)
        with patch.dict(S.PROFILES, {"release741": self.config}):
            result = S.restore_overwritten_foundation(self.root, self.fetch, symbols=symbols)
        self.assertEqual([str(external)], result["restored"])
        self.assertEqual(self.config["pin"], S.file_hash(external))

    def test_approved_package_is_not_downloaded_again(self):
        self.collision.write_bytes(self.approved_source.read_bytes())
        result = self.restore()
        self.assertEqual("already-approved", result["action"])
        self.assertEqual(0, self.calls)

    def test_unknown_hash_fails_without_download_or_replacement(self):
        before = self.collision.read_bytes()
        self.config["testPin"] = "0" * 64
        with self.assertRaisesRegex(S.GateError, "Unapproved Foundation"):
            self.restore()
        self.assertEqual(before, self.collision.read_bytes())
        self.assertEqual(0, self.calls)

    def test_wrong_archive_hash_leaves_the_collision(self):
        before = self.collision.read_bytes()
        self.config["artifacts"]["Apps"] = (self.config["artifacts"]["Apps"][0], "1" * 64)
        with self.assertRaisesRegex(S.GateError, "Changed Foundation Apps artifact"):
            self.restore()
        self.assertEqual(before, self.collision.read_bytes())


class BaselineSymbolFetch(unittest.TestCase):
    def nupkg(self, package_id, version, identity, dependencies=()):
        temp = Path(self.temp.name) / f'{package_id}.app'
        fixture(temp, identity)
        deps = ''.join(f'<dependency id="{d}" version="{r}" />' for d, r in dependencies)
        spec = (f'<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"><metadata>'
                f'<id>{package_id}</id><version>{version}</version><dependencies>{deps}</dependencies>'
                f'</metadata></package>')
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.writestr(f'{package_id}.nuspec', spec)
            archive.writestr(f'Microsoft_{identity["name"]}_{version}.app', temp.read_bytes())
        return buffer.getvalue()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base_id = 'microsoft.baseapplication.symbols.437dbf0e-84ff-417a-965d-ed2bb9650972'
        app = dict(id=str(uuid.uuid4()), publisher='Microsoft', name='Application', version='28.3.52162.52273')
        base = dict(id=str(uuid.uuid4()), publisher='Microsoft', name='Base Application', version='28.3.52162.52273')
        self.responses = {
            'feed/microsoft.application.symbols/index.json':
                json.dumps({'versions': ['28.0.46665.54008', '28.3.52162.52273', '28.4.1.1', '29.0.0.0-beta']}).encode(),
            'feed/microsoft.application.symbols/28.3.52162.52273/microsoft.application.symbols.28.3.52162.52273.nupkg':
                self.nupkg('Microsoft.Application.symbols', '28.3.52162.52273', app,
                           [(base_id, '[28.3.0.0,28.4.0.0)'), ('Microsoft.Platform.symbols', '[28.0.0.0,28.1.0.0)')]),
            f'feed/{base_id}/index.json': json.dumps({'versions': ['28.3.52162.52273', '28.4.1.1']}).encode(),
            f'feed/{base_id}/28.3.52162.52273/{base_id}.28.3.52162.52273.nupkg':
                self.nupkg(base_id, '28.3.52162.52273', base),
        }

    def test_earliest_matching_application_and_dependencies_without_platform(self):
        folder = Path(self.temp.name) / 'out'
        written = F.download('28.3.0.0', folder, feed='feed/', fetcher=self.responses.__getitem__)
        self.assertEqual(['Application', 'Base Application'], [item['name'] for item in written])
        self.assertEqual({'28.3.52162.52273'}, {item['version'] for item in written})
        self.assertEqual(2, len(list(folder.glob('*.app'))))

    def test_unmatched_requirement_and_bad_input_refused(self):
        with self.assertRaisesRegex(F.GateError, 'No symbol package version'):
            F.download('28.9.0.0', Path(self.temp.name) / 'none', feed='feed/', fetcher=self.responses.__getitem__)
        with self.assertRaisesRegex(F.GateError, 'Invalid Application requirement'):
            F.download('28.3', Path(self.temp.name) / 'none', feed='feed/', fetcher=self.responses.__getitem__)

    def test_version_ranges(self):
        self.assertEqual(((28, 3, 0, 0), (28, 4, 0, 0), None), F.parse_range('[28.3.0.0,28.4.0.0)'))
        self.assertEqual(((28, 3, 1, 2), None, (28, 3, 1, 2)), F.parse_range('[28.3.1.2]'))
        self.assertEqual(((28, 3, 0, 0), None, None), F.parse_range('28.3.0.0'))


class PrecompileCache(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.cache = self.root / '.packages'
        self.cache.mkdir()
        self.identities = {}
        for folder, app_id in [('app', '672df32a-a0c5-4a22-b591-0efa38023e95'),
                               ('test', '7cdb530b-b74b-446b-9ece-80e2b911bfb3')]:
            project = self.root / folder
            project.mkdir()
            identity = dict(id=app_id, publisher='Origo', name=folder, version='28.3.0.0')
            self.identities[folder] = identity
            (project / 'app.json').write_text(json.dumps(identity))

    def run_prune(self, project='app'):
        return P.prune(self.root, self.root / project, self.cache)

    def test_previous_self_aliases_removed_but_dependencies_and_baseline_preserved(self):
        previous = dict(self.identities['app'], version='28.3.0.122')
        for name in ('previous.app', 'renamed.app'):
            fixture(self.cache / name, previous)
        fixture(self.cache / 'Foundation.app')
        dependency_bytes = (self.cache / 'Foundation.app').read_bytes()
        baseline = self.root / 'previousApps'
        baseline.mkdir()
        fixture(baseline / 'previous.app', previous)
        result = self.run_prune()
        self.assertEqual(['previous.app', 'renamed.app'], [x['file'] for x in result['removed']])
        self.assertEqual(dependency_bytes, (self.cache / 'Foundation.app').read_bytes())
        self.assertTrue((baseline / 'previous.app').exists())
        self.assertEqual([], self.run_prune()['removed'])

    def test_test_compile_keeps_product_dependency_and_removes_only_test_self(self):
        fixture(self.cache / 'Product.app', self.identities['app'])
        fixture(self.cache / 'Tests.app', self.identities['test'])
        self.assertEqual('Tests.app', self.run_prune('test')['removed'][0]['file'])
        self.assertTrue((self.cache / 'Product.app').exists())

    def test_dependency_resource_validation_stays_with_unchanged_gate(self):
        # A large dependency must reach the gate's own catalog/cache policy;
        # self-cache preparation does not apply the shipping-app entry budget.
        dependency = self.cache / 'LargeLibrary.app'
        fixture(dependency)
        with zipfile.ZipFile(dependency, 'a') as archive:
            for index in range(4100):
                archive.writestr(f'Library/{index}.txt', b'fixture')
        before = dependency.read_bytes()
        fixture(self.cache / 'Self.app', self.identities['app'])
        self.assertEqual('Self.app', self.run_prune()['removed'][0]['file'])
        self.assertEqual(before, dependency.read_bytes())

    def test_upgrade_baseline_and_dependencies_preserved_outside_compile_cache(self):
        previous = dict(self.identities['app'], version='28.3.0.122')
        fixture(self.cache / 'Previous.app', previous)
        original = (self.cache / 'Previous.app').read_bytes()
        fixture(self.cache / 'Foundation.app')
        catalog = self.root / 'compiler-symbols'
        catalog.mkdir()
        fixture(catalog / 'Microsoft.app')
        cop = self.root / 'app/AppSourceCop.json'
        cop.write_text(json.dumps({'Version': previous['version'], 'mandatoryAffixes': ['ori']}))
        result = P.prune(self.root, self.root / 'app', self.cache, catalog)
        baseline = Path(result['baseline']['path'])
        self.assertEqual(original, (baseline / 'Baseline.app').read_bytes())
        self.assertEqual((self.cache / 'Foundation.app').read_bytes(), (baseline / 'Foundation.app').read_bytes())
        self.assertEqual((catalog / 'Microsoft.app').read_bytes(), (baseline / 'Microsoft.app').read_bytes())
        settings = json.loads(cop.read_text())
        self.assertEqual(previous['version'], settings['Version'])
        self.assertEqual(['ori'], settings['mandatoryAffixes'])
        self.assertEqual(str(baseline), settings['baselinePackageCachePath'])
        self.assertFalse((self.cache / 'Previous.app').exists())
        self.assertEqual([], P.prune(self.root, self.root / 'app', self.cache, catalog)['removed'])

    def baseline_on_newer_application(self):
        previous = dict(self.identities['app'], version='28.3.3.161')
        fixture(self.cache / 'Previous.app', dict(previous, application='28.3.0.0'))
        catalog = self.root / 'compiler-symbols'
        catalog.mkdir()
        app_id = 'c1335042-3002-4257-bf8a-75c898ccb1b8'
        fixture(catalog / 'Microsoft_Application_28.0.app',
                dict(id=app_id, publisher='Microsoft', name='Application', version='28.0.46665.54008'))
        fixture(catalog / 'Microsoft_System_28.0.app',
                dict(id=str(uuid.uuid4()), publisher='Microsoft', name='System', version='28.0.46665.54008'))
        (self.root / 'app/AppSourceCop.json').write_text(json.dumps({'version': previous['version']}))
        return catalog, app_id

    def test_baseline_on_newer_application_is_reported_unsatisfied(self):
        catalog, _ = self.baseline_on_newer_application()
        result = P.prune(self.root, self.root / 'app', self.cache, catalog)['baseline']
        self.assertEqual('28.3.0.0', result['applicationRequired'])
        self.assertEqual('28.0.46665.54008', result['applicationAvailable'])
        self.assertFalse(result['applicationSatisfied'])

    def test_baseline_symbols_replace_floor_packages_in_baseline_cache_only(self):
        catalog, app_id = self.baseline_on_newer_application()
        P.prune(self.root, self.root / 'app', self.cache, catalog)
        newer = self.root / '.buildartifacts/AppSourceBaselineSymbols/28.3.0.0'
        newer.mkdir(parents=True)
        fixture(newer / 'Microsoft_Application_28.3.app',
                dict(id=app_id, publisher='Microsoft', name='Application', version='28.3.52162.52273'))
        result = P.prune(self.root, self.root / 'app', self.cache, catalog, newer)['baseline']
        self.assertTrue(result['applicationSatisfied'])
        self.assertEqual('28.3.52162.52273', result['applicationAvailable'])
        owned = Path(result['path'])
        names = sorted(path.name for path in owned.glob('*.app'))
        self.assertEqual(['Baseline.app', 'Microsoft_Application_28.3.app', 'Microsoft_System_28.0.app'], names)
        # The compile floor catalog is untouched.
        self.assertTrue((catalog / 'Microsoft_Application_28.0.app').exists())

    def test_baseline_symbol_override_must_be_microsoft_and_owned(self):
        catalog, _ = self.baseline_on_newer_application()
        foreign = self.root / '.buildartifacts/AppSourceBaselineSymbols/x'
        foreign.mkdir(parents=True)
        fixture(foreign / 'Other.app', dict(id=str(uuid.uuid4()), publisher='Contoso', name='Application', version='28.3.0.0'))
        with self.assertRaisesRegex(P.GateError, 'Microsoft package'):
            P.prune(self.root, self.root / 'app', self.cache, catalog, foreign)
        with tempfile.TemporaryDirectory() as outside:
            with self.assertRaisesRegex(P.GateError, 'outside owned workspace'):
                P.prune(self.root, self.root / 'app', self.cache, catalog, outside)

    def test_missing_upgrade_baseline_refuses_before_removing_self(self):
        fixture(self.cache / 'Self.app', self.identities['app'])
        cop = self.root / 'app/AppSourceCop.json'
        cop.write_text(json.dumps({'Version': '28.3.0.122'}))
        with self.assertRaisesRegex(P.GateError, 'Required upgrade baseline missing'):
            self.run_prune()
        self.assertTrue((self.cache / 'Self.app').exists())
        self.assertEqual({'Version': '28.3.0.122'}, json.loads(cop.read_text()))

    def test_foreign_cache_and_unknown_project_refused(self):
        with self.assertRaisesRegex(P.GateError, 'owned workspace'):
            P.prune(self.root, self.root / 'app', self.root)
        with self.assertRaisesRegex(P.GateError, 'Unknown compiling project'):
            P.prune(self.root, self.root, self.cache)

    def test_corrupt_input_prevents_partial_cleanup(self):
        fixture(self.cache / 'a-self.app', self.identities['app'])
        (self.cache / 'z-corrupt.app').write_bytes(b'broken')
        with self.assertRaises(P.GateError):
            self.run_prune()
        self.assertTrue((self.cache / 'a-self.app').exists())

    def test_symlink_and_identity_collision_refused(self):
        fixture(self.root / 'outside.app', self.identities['app'])
        (self.cache / 'linked.app').symlink_to(self.root / 'outside.app')
        with self.assertRaises(P.GateError):
            self.run_prune()
        (self.cache / 'linked.app').unlink()
        fixture(self.cache / 'collision.app', dict(self.identities['app'], publisher='Other'))
        with self.assertRaisesRegex(P.GateError, 'unexpected publisher'):
            self.run_prune()
        self.assertTrue((self.cache / 'collision.app').exists())



if __name__ == "__main__":
    unittest.main(verbosity=2)
