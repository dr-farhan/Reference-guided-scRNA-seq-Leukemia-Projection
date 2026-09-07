"""Lightweight tests for configuration and the published analysis boundary."""
from pathlib import Path
import re
import unittest
import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]

class WorkflowContracts(unittest.TestCase):
    def test_default_configuration(self):
        schema = yaml.safe_load((ROOT / 'workflow/config.schema.yaml').read_text())
        config = yaml.safe_load((ROOT / 'config/config.yaml').read_text())
        Draft202012Validator(schema).validate(config)
        invalid = {**config, 'analysis': {**config['analysis'], 'knn_probability_cutoff': 1.1}}
        self.assertTrue(list(Draft202012Validator(schema).iter_errors(invalid)))

    def test_analysis_has_no_candidate_state_code(self):
        for path in (ROOT / 'workflow/scripts').glob('*.R'):
            self.assertIsNone(re.search(r'lsc|blast|lspc|score_Genesets_AUCell', path.read_text(), re.I), path.name)

    def test_no_machine_specific_paths_in_workflow(self):
        for path in (ROOT / 'workflow').rglob('*'):
            if path.is_file() and path.suffix in {'.R', '.py', '.yaml'}:
                self.assertNotIn('/home/sahmad', path.read_text())

if __name__ == '__main__':
    unittest.main()
