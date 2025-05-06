# SEC-bench

## Specify a subset of tasks to run infer

If you would like to specify a list of tasks you'd like to benchmark on, you could create a `config.toml` under `./evaluation/benchmarks/secbench/` folder, and put a list attribute named `selected_ids`, e.g.

```toml
selected_ids = ['openjpeg.cve-2024-56827']
```

Then only these tasks (rows whose `instance_id` is in the above list) will be evaluated. In this case, `eval_limit` option applies to tasks that are in the `selected_ids` list.

After running the inference, you will obtain a `output.jsonl` (by default it will be saved to `evaluation/evaluation_outputs`).


## Run Inference

```bash
./evaluation/benchmarks/secbench/scripts/run_infer.sh llm.eval_claude_3_7 HEAD CodeActAgent 10 30 1 hwiwonl/SEC-bench test
./evaluation/benchmarks/secbench/scripts/run_infer.sh llm.eval_gpt_4o HEAD CodeActAgent 10 30 1 hwiwonl/SEC-bench test
./evaluation/benchmarks/secbench/scripts/run_infer.sh llm.eval_gemini-1-5-pro HEAD CodeActAgent 10 30 1 hwiwonl/SEC-bench test
./evaluation/benchmarks/secbench/scripts/run_infer.sh llm.eval_gemini-2-0-flash HEAD CodeActAgent 10 30 1 hwiwonl/SEC-bench test
./evaluation/benchmarks/secbench/scripts/run_infer.sh llm.eval_gemini-2-0-think HEAD CodeActAgent 10 30 1 hwiwonl/SEC-bench test
```

## Run Patch Evaluation

```bash
poetry run python evaluation/benchmarks/secbench/run_eval.py --input-file <path-to-output.jsonl>
```
