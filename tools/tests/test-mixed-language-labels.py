"""Exercise Locked property parsing through the complete AL source scanner.

Run with python -I tools/tests/test-mixed-language-labels.py.
PWSH and MIXED_LABEL_SCANNER can select a PowerShell binary and baseline scanner.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCANNER = Path(os.environ.get('MIXED_LABEL_SCANNER', Path(__file__).resolve().parents[1] / 'Test-MixedLanguageLabels.ps1'))
PWSH = os.environ.get('PWSH', 'pwsh')

CASES = {
    'translated_protocol_comment': ("Comment = 'is-IS=Stilltu allowBlocked=true aðeins ef breyting er fyrirhuguð.'", False),
    'quoted_property_comment': ("Comment = 'is-IS=Do not set Locked = true here.'", False),
    'escaped_quote_comment': ("Comment = 'is-IS=It''s translated; Locked = true is only text.'", False),
    'comment_with_property_separator': ("Comment = 'is-IS=Text, Locked = true, text.'", False),
    'explicit_false': ("Locked = false, Comment = 'is-IS=allowBlocked=true'", False),
    'locked_before_comment': ("Locked = true, Comment = 'is-IS=Text.'", True),
    'locked_after_comment': ("Comment = 'is-IS=Text, Locked = false', Locked = true", True),
    'mixed_case_whitespace': ("Comment = 'is-IS=Text.', lOcKeD\n =\tTrUe", True),
    'locked_with_escaped_comment': ("Comment = 'It''s text, Locked = false.', Locked = true", True),
    'locked_block_comment': ("Locked /* explanation */ = true", True),
}


class LabelProperties(unittest.TestCase):
    def check_case(self, scope, properties, locked):
        with tempfile.TemporaryDirectory(prefix='mixed-label-properties-') as tmp:
            root = Path(tmp)
            (root / 'src').mkdir()
            label = "RefusalErr: Label 'The item is blocked.', " + properties + ';'
            global_vars = 'var\n    ' + label if scope == 'global' else ''
            local_vars = 'var\n    ' + label if scope == 'local' else ''
            (root / 'src' / 'Fixture.Codeunit.al').write_text(
                'codeunit 1 "Fixture"\n{\n' + global_vars + '\n'
                'procedure Refuse()\n' + local_vars + '\nbegin\n'
                '    Error(RefusalErr);\nend;\n}\n', encoding='utf-8')
            run = subprocess.run([PWSH, '-NoLogo', '-NoProfile', '-File', str(SCANNER),
                                  '-AppFolder', str(root)], capture_output=True, text=True, timeout=60)
            output = run.stdout + run.stderr
            self.assertEqual(run.returncode, 1 if locked else 0, output)
            self.assertEqual('[locked-label]' in output, locked, output)
            self.assertEqual('[mixed-language]' in output, locked, output)
        self.assertFalse(root.exists(), 'Owned fixture directory must be removed')


def make_test(scope, properties, locked):
    def test(self):
        self.check_case(scope, properties, locked)
    return test


for scope in ('global', 'local'):
    for name, (properties, locked) in CASES.items():
        setattr(LabelProperties, 'test_' + scope + '_' + name, make_test(scope, properties, locked))

if __name__ == '__main__':
    unittest.main(verbosity=2)
