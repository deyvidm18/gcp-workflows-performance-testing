import concurrent.futures
import os
import time
from google.cloud import workflows_v1
from google.cloud.workflows import executions_v1
from google.cloud.workflows.executions_v1.types import Execution

PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT") # Change to your Google Cloud Project ID
LOCATION = os.getenv("LOCATION", "northamerica-south1") # Change to your location
WORKFLOW_ID = os.getenv("WORKFLOW") # Change to your workflow name

def execute_workflow(project: str, location: str, workflow: str) -> Execution:
    """Execute a workflow and return the execution response."""
    execution_client = executions_v1.ExecutionsClient()
    workflows_client = workflows_v1.WorkflowsClient()

    parent = workflows_client.workflow_path(project, location, workflow)
    response = execution_client.create_execution(request={"parent": parent})
    return response

def test_workflow_concurrency(project: str, location: str, workflow: str, concurrency: int):
    """Tests the workflow with a specified concurrency level."""
    start_time = time.time()
    results = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(execute_workflow, project, location, workflow) for _ in range(concurrency)]

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
    concurrency_levels = [5, 10, 50, 100]

    for concurrency in concurrency_levels:
        test_workflow_concurrency(PROJECT, LOCATION, WORKFLOW_ID, concurrency)

if __name__ == "__main__":
    main()