import unittest

from scripts.check_release import check


class ReleaseChecks(unittest.TestCase):
    def service(self, state="COMPLETED", revision="requested"):
        return {"taskDefinition": revision, "desiredCount": 2, "runningCount": 2,
                "deployments": [{"rolloutState": state}]}

    def test_stable_counts_before_rollout_completion_require_waiting(self):
        self.assertFalse(check(self.service("IN_PROGRESS"), "requested"))
        self.assertTrue(check(self.service(), "requested"))

    def test_automatic_rollback_is_not_release_success(self):
        with self.assertRaisesRegex(ValueError, "rolled back"):
            check(self.service(revision="previous"), "requested")

    def test_failed_rollout_is_not_retried_as_convergence(self):
        with self.assertRaisesRegex(ValueError, "failed"):
            check(self.service("FAILED"), "requested")

    def test_old_deployment_must_finish_draining(self):
        service = self.service()
        service["deployments"].append({"rolloutState": "COMPLETED"})
        self.assertFalse(check(service, "requested"))

    def test_two_task_capacity_is_required(self):
        service = self.service()
        service["desiredCount"] = 1
        with self.assertRaisesRegex(ValueError, "two tasks"):
            check(service, "requested")
