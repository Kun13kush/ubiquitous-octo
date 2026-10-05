import unittest
from scripts.render_task import render


class RenderTests(unittest.TestCase):
    def test_preserves_security_and_removes_response_fields(self):
        task = {"family": "finzla-production", "taskDefinitionArn": "old", "revision": 4,
                "executionRoleArn": "exec", "taskRoleArn": "task", "containerDefinitions": [
                    {"name": "app", "image": "old", "readonlyRootFilesystem": True, "user": "10001:10001", "environment": [{"name": "APP_ENV", "value": "production"}]},
                    {"name": "sidecar", "image": "unchanged"}]}
        result = render(task, "new@sha256:digest")
        self.assertNotIn("revision", result)
        self.assertNotIn("taskDefinitionArn", result)
        self.assertTrue(result["containerDefinitions"][0]["readonlyRootFilesystem"])
        self.assertEqual(result["taskRoleArn"], "task")
        self.assertEqual(result["containerDefinitions"][0]["image"], "new@sha256:digest")
        self.assertEqual(result["containerDefinitions"][1]["image"], "unchanged")

    def test_missing_app_fails(self):
        with self.assertRaises(ValueError):
            render({"containerDefinitions": []}, "new")
