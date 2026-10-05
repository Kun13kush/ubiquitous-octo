"""Exercise deployment decisions with fake AWS/Docker/curl; no network or AWS."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FAKE = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
name = Path(sys.argv[0]).name
scenario = os.environ['SCENARIO']
log = Path(os.environ['CALL_LOG'])
with log.open('a') as stream:
    stream.write(json.dumps([name] + args) + '\\n')
old = 'arn:aws:ecs:eu-west-1:123456789012:task-definition/finzla:1'
new = 'arn:aws:ecs:eu-west-1:123456789012:task-definition/finzla:2'
state = Path(os.environ['MOCK_STATE'])
if name == 'docker':
    if args[0] == 'login': sys.stdin.read()
    sys.exit(0)
if name == 'sleep': sys.exit(0)
if name == 'curl':
    if args[-1].endswith('/version'):
        print(json.dumps({'version': 'wrong' if scenario in ('wrong-version', 'rollback-fails') else 'release123'}))
    else: print('{"status":"ok"}')
    sys.exit(0)
if args[:2] == ['ecr', 'get-login-password']: print('temporary-test-token')
elif args[:2] == ['ecr', 'describe-images']: print('sha256:' + 'a' * 64)
elif args[:2] == ['ecs', 'describe-task-definition']:
    print(json.dumps({'family':'finzla', 'revision':1, 'taskDefinitionArn':old, 'containerDefinitions':[{'name':'app','image':'old','readonlyRootFilesystem':True}]}))
elif args[:2] == ['ecs', 'register-task-definition']: print(new)
elif args[:2] == ['ecs', 'update-service']:
    target = args[args.index('--task-definition') + 1]
    state.write_text(target)
    if scenario == 'update-timeout' and target == new: sys.exit(1)
    print('{}')
elif args[:3] == ['ecs', 'wait', 'services-stable']:
    if scenario == 'auto-rollback' and state.read_text() == new: state.write_text(old)
    if scenario == 'rollback-fails' and state.read_text() == old: sys.exit(1)
elif args[:2] == ['ecs', 'describe-services']:
    active = state.read_text() if state.exists() else old
    if '--query' in args: print(active)
    else: print(json.dumps({'services':[{'taskDefinition':active, 'desiredCount':2, 'runningCount':2, 'deployments':[{'rolloutState':'COMPLETED'}]}]}))
else:
    print('Unsupported mock command', args, file=sys.stderr)
    sys.exit(2)
'''


class DeploymentTests(unittest.TestCase):
    def exercise(self, scenario):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            for name in ('aws', 'docker', 'curl', 'sleep'):
                tool = directory / name
                tool.write_text(FAKE)
                tool.chmod(0o755)
            log = directory / 'calls.jsonl'
            env = dict(os.environ, PATH=f"{folder}:{os.environ['PATH']}", SCENARIO=scenario,
                       CALL_LOG=str(log), MOCK_STATE=str(directory / 'state'),
                       ECR_REPOSITORY='123456789012.dkr.ecr.eu-west-1.amazonaws.com/finzla',
                       ECS_CLUSTER='finzla', ECS_SERVICE='finzla', BASE_URL='https://api.example.com',
                       RELEASE='release123', AWS_REGION='eu-west-1')
            result = subprocess.run(['bash', 'scripts/deploy.sh'], cwd=ROOT, env=env,
                                    capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            updates = [call for call in calls if call[:3] == ['aws', 'ecs', 'update-service']]
            return result, updates

    def test_success_deploys_once(self):
        result, updates = self.exercise('success')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(updates), 1)
        self.assertTrue(updates[0][updates[0].index('--task-definition') + 1].endswith(':2'))

    def test_stable_automatic_rollback_is_failure(self):
        self.assert_rollback('auto-rollback')

    def test_wrong_public_version_rolls_back(self):
        self.assert_rollback('wrong-version')

    def test_update_timeout_rolls_back(self):
        self.assert_rollback('update-timeout')

    def test_failed_rollback_is_reported_unconfirmed(self):
        result, updates = self.exercise('rollback-fails')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(updates), 2)
        self.assertIn('ROLLBACK UNCONFIRMED', result.stderr)
        self.assertNotIn('Previous task definition restored', result.stderr)

    def assert_rollback(self, scenario):
        result, updates = self.exercise(scenario)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(updates), 2, result.stderr)
        self.assertTrue(updates[-1][updates[-1].index('--task-definition') + 1].endswith(':1'))
        self.assertIn('Previous task definition restored', result.stderr)
