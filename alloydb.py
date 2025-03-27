import concurrent.futures
import os
import time
import random
from google.cloud import workflows_v1
from google.cloud.workflows import executions_v1
from google.cloud.workflows.executions_v1.types import Execution

PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION = os.getenv("LOCATION", "northamerica-south1")  
WORKFLOW_ID = "workflow-alloydb-run"  


def execute_workflow(project: str, location: str, workflow: str, client_id: int) -> Execution:
    """Execute a alloydb and return the execution response."""
    execution_client = executions_v1.ExecutionsClient()
    workflows_client = workflows_v1.WorkflowsClient()
    execution = Execution(argument = f'{{"clientId": {client_id}}}')

    parent = workflows_client.workflow_path(project, location, workflow)

    response = execution_client.create_execution(parent=parent, execution=execution)
    return response


def test_workflow_concurrency(project: str, location: str, workflow: str, concurrency: int):
    """Tests the workflow with a specified concurrency level."""
    start_time = time.time()
    results = []
    client_ids = random.sample(range(1000), concurrency)  # Generate unique random client IDs

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [
            executor.submit(execute_workflow, project, location, workflow, client_id)
            for client_id in client_ids
        ]

        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())

    end_time = time.time()
    elapsed_time = end_time - start_time

    print(f"Concurrency: {concurrency}")
    print(f"Elapsed Time: {elapsed_time:.2f} seconds")
    print(f"Total Results: {len(results)}")
    print("-" * 20)
    return elapsed_time


def main():
    concurrency = 100  # Set concurrency level to 100
    test_workflow_concurrency(PROJECT, LOCATION, WORKFLOW_ID, concurrency)


if __name__ == "__main__":
    main()
