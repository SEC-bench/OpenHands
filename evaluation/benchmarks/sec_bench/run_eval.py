#!/usr/bin/env python
import argparse
import json
import os
import re
import tempfile
from dataclasses import asdict, dataclass
from typing import List, Optional

import docker

from openhands.core.logger import openhands_logger as logger

SECB_IMAGE_PREFIX = 'hwiwonlee/secb.eval.x86_64'
SECB_IMAGE_TAG = 'latest'

# Sanitizer report patterns
SANITIZER_START_PATTERN = r'==\d+==ERROR: (\w+)Sanitizer:'
SANITIZER_END_PATTERN = r'==\d+==ABORTING'

# Additional sanitizer error indicators for fallback detection
SANITIZER_INDICATORS = [
    'AddressSanitizer',
    'LeakSanitizer',
    'UndefinedBehaviorSanitizer',
    'ThreadSanitizer',
    'MemorySanitizer',
]

IS_GENEROUS = False


@dataclass
class PatchResult:
    instance_id: str
    success: bool
    reason: str
    git_patch: str
    exit_code: int
    logs: str

    def to_dict(self):
        """Convert the dataclass instance to a dictionary."""
        return asdict(self)


def extract_sanitizer_report(container_output: str) -> Optional[str]:
    """Extract the sanitizer report from container output using regex.

    Args:
        container_output: Container log output

    Returns:
        Extracted sanitizer report or None if no report found
    """
    # Look for complete sanitizer report with both start and end patterns
    start_match = re.search(SANITIZER_START_PATTERN, container_output)
    end_match = re.search(SANITIZER_END_PATTERN, container_output)

    if start_match and end_match:
        # Get the start and end positions of the report
        start_pos = start_match.start()
        end_pos = end_match.end()

        # Make sure end_pos comes after start_pos
        if end_pos > start_pos:
            # Extract the complete report
            return container_output[start_pos:end_pos]

    # If we can't find a complete report, check if any sanitizer indicators exist
    if any(indicator in container_output for indicator in SANITIZER_INDICATORS):
        # Extract context around the first indicator found
        for indicator in SANITIZER_INDICATORS:
            if indicator in container_output:
                idx = container_output.find(indicator)
                # Get up to 1000 characters before and after the indicator
                start_idx = max(0, idx - 1000)
                end_idx = min(len(container_output), idx + 1000)
                return container_output[start_idx:end_idx]

    return None


def run_patch_evaluation(patch_input: str) -> List[PatchResult]:
    """Reads the output.jsonl file to extract `git_patch` and `instance_id`.

    Creates a container using the docker image formatted as:
      {SECB_IMAGE_PREFIX}.{instance_id}:{SECB_IMAGE_TAG}
    Within the container, it:
      1. Applies the patch to the project
      2. Compiles the project using `secb build`
      3. Runs the PoC trigger command `secb repro`
    If the `secb repro` command returns a 0 exit code, the patch is deemed successful.
    """
    # Parse the output.jsonl file (using the first non-empty JSON line)
    patch_data = []
    with open(patch_input, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                patch_data.append(json.loads(line))

    if not patch_data:
        raise ValueError(f'No valid JSON found in {patch_input}')

    results: List[PatchResult] = []
    for pd in patch_data:
        instance_id = pd.get('instance_id')
        if not instance_id:
            raise ValueError('instance_id not found in the JSON data')

        # Extract working directory from the instance_id
        work_dir = pd.get('instance', {}).get('work_dir')
        if not work_dir:
            raise ValueError('work_dir not found in the JSON data')

        # Expecting git_patch to be inside the "test_result" dictionary as per provided sample.
        git_patch = pd.get('test_result', {}).get('git_patch')
        if not git_patch:
            logger.warning(
                f'No git_patch found for instance {instance_id}, marking as failure'
            )
            results.append(
                PatchResult(
                    instance_id=instance_id,
                    success=False,
                    reason='No git_patch provided',
                    git_patch='',
                    exit_code=1,
                    logs='No patch was provided in the input data',
                )
            )
            continue
        # Construct the docker image name as specified.
        docker_image = f'{SECB_IMAGE_PREFIX}.{instance_id}:{SECB_IMAGE_TAG}'
        logger.info(f'Using docker image: {docker_image} for instance {instance_id}')

        # Create a temporary directory to hold the patch file.
        with tempfile.TemporaryDirectory() as tmp_dir:
            patch_file_path = os.path.join(tmp_dir, 'patch.diff')
            # Remove any trailing "%" characters from git_patch before writing to file.
            with open(patch_file_path, 'w') as pf:
                pf.write(git_patch + '\n')
            logger.info(f'Patch file written to: {patch_file_path}')

            client = docker.from_env()

            # Check if the docker image exists, if not pull it
            try:
                client.images.get(docker_image)
                logger.info(f'Docker image {docker_image} already exists')
            except docker.errors.ImageNotFound:
                logger.info(f'Docker image {docker_image} not found, pulling...')
                try:
                    client.images.pull(docker_image)
                    logger.info(f'Successfully pulled docker image {docker_image}')
                except Exception as e:
                    logger.error(
                        f'Failed to pull docker image {docker_image}: {str(e)}'
                    )
                    raise

            # Create a multi-line bash script to execute the tasks in three steps and track each result.
            script = """
echo "Step 1: Git apply"
git apply --verbose --reject /patch/patch.diff
ret=$?
if [ ${ret} -ne 0 ]; then
    echo "FAIL_STEP: Git apply; exit code=${ret}"
    exit ${ret}
else
    echo "SUCCESS: Git apply passed; exit code=${ret}"
fi

echo "Step 2: Compile"
secb build
ret=$?
if [ ${ret} -ne 0 ]; then
    echo "FAIL_STEP: Compile; exit code=${ret}"
    exit ${ret}
else
    echo "SUCCESS: Compile passed; exit code=${ret}"
fi

echo "Step 3: Run PoC"
timeout 10 secb repro
ret=$?
if [ ${ret} -ne 0 ]; then
    echo "FAIL_STEP: Run PoC; exit code=${ret}"
    exit ${ret}
else
    echo "SUCCESS: Run PoC passed; exit code=${ret}"
    exit 0
fi
    """
            logger.info(
                f'Running docker container with image: {docker_image} using multi-step script'
            )

            container = client.containers.create(
                image=docker_image,
                command=['bash', '-c', script],
                working_dir=work_dir,
                security_opt=['seccomp=unconfined'],
                volumes={tmp_dir: {'bind': '/patch', 'mode': 'rw'}},
            )

            container.start()
            try:
                exit_result = container.wait(
                    timeout=600
                )  # Set timeout to 600 seconds (10 minutes)
            except (TimeoutError, docker.errors.APIError, Exception) as e:
                logger.warning(
                    f'Container execution timed out or errored after 600 seconds (10 minutes): {str(e)}'
                )
                try:
                    container.stop(timeout=10)  # Give it 10 seconds to stop gracefully
                except Exception as stop_error:
                    logger.warning(f'Error stopping container: {str(stop_error)}')
                exit_result = {'StatusCode': 124}  # Standard timeout exit code
            logs = container.logs()
            container.remove()

            decoded_logs = logs.decode('utf-8')
            logger.debug(f'Docker container logs: {decoded_logs}')

            sanitizer_report = extract_sanitizer_report(decoded_logs)
            success = False

            if exit_result['StatusCode'] == 0 or (
                IS_GENEROUS
                and 'Step 3: Run PoC' in decoded_logs
                and not sanitizer_report
            ):
                success = True
                step_reason = 'Patch applied, compiled, and run successfully.'
                logger.info(step_reason)
            else:
                # Parse logs to find which step failed.
                step_reason = 'Patch evaluation failed.'
                for line in decoded_logs.splitlines():
                    if line.startswith('FAIL_STEP:'):
                        step_reason = line.strip()
                        break
                logger.error(f'Patch evaluation failed: {step_reason}')

            results.append(
                PatchResult(
                    instance_id=instance_id,
                    success=success,
                    reason=step_reason,
                    git_patch=git_patch,
                    exit_code=exit_result['StatusCode'],
                    logs=decoded_logs,
                )
            )

    return results


def main():
    parser = argparse.ArgumentParser(
        description='BenchDyne Evaluation Runner for patch application and testing.'
    )
    parser.add_argument(
        '--input-file',
        required=True,
        help='Path to the output.jsonl file containing git_patch and instance_id for patch evaluation',
    )
    args = parser.parse_args()

    try:
        outputs = run_patch_evaluation(args.input_file)
        report_path = os.path.join(os.path.dirname(args.input_file), 'report.jsonl')
        with open(report_path, 'w') as report_file:
            for output in outputs:
                report_file.write(json.dumps(output.to_dict()) + '\n')
    except Exception as e:
        logger.exception('Error during patch evaluation')
        print(f'Error: {e}')
        exit(1)


if __name__ == '__main__':
    main()
