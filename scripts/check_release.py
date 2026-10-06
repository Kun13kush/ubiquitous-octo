"""Distinguish a completed exact release from ECS convergence and rollback."""
import json
import sys


def check(service, expected):
    if service["taskDefinition"] != expected:
        raise ValueError("ECS selected another revision; release was rolled back")
    if service["desiredCount"] < 2:
        raise ValueError("Service requires at least two tasks")
    if any(deployment.get("rolloutState") == "FAILED" for deployment in service["deployments"]):
        raise ValueError("ECS deployment failed")
    return (service["runningCount"] == service["desiredCount"]
            and len(service["deployments"]) == 1
            and service["deployments"][0]["rolloutState"] == "COMPLETED")


if __name__ == "__main__":
    with open(sys.argv[1]) as source:
        service = json.load(source)["services"][0]
    try:
        sys.exit(0 if check(service, sys.argv[2]) else 3)
    except ValueError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
