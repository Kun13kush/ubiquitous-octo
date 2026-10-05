"""Render a new revision from the active task; retain its security settings."""
import json
import sys

ALLOWED = {"family", "taskRoleArn", "executionRoleArn", "networkMode", "containerDefinitions", "volumes", "placementConstraints", "requiresCompatibilities", "cpu", "memory", "tags", "pidMode", "ipcMode", "proxyConfiguration", "inferenceAccelerators", "ephemeralStorage", "runtimePlatform", "enableFaultInjection"}


def render(task, image):
    result = {key: value for key, value in task.items() if key in ALLOWED}
    apps = [container for container in result["containerDefinitions"] if container["name"] == "app"]
    if len(apps) != 1:
        raise ValueError("Expected exactly one app container")
    apps[0]["image"] = image
    return result


if __name__ == "__main__":
    with open(sys.argv[1]) as source:
        print(json.dumps(render(json.load(source), sys.argv[2])))
