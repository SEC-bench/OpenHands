#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 1 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 <mode> [max_iterations] [label] [num_workers]"
    echo "Modes: infer, eval, view"
    exit 1
fi

mode=$1
max_iterations=${2:-50}  # Default to 50 if not provided
label=${3:-"eval"}  # Default to "eval" if not provided
num_workers=${4:-1}  # Default to 1 if not provided

clear

# Execute based on the mode
if [ "$mode" = "infer" ]; then
    ## PoC
    ./evaluation/benchmarks/sec_bench/scripts/run_infer.sh llm.eval_sonnet HEAD CodeActAgent 80 $max_iterations $num_workers SEC-bench/SEC-bench $label 0.1 poc

    # ./evaluation/benchmarks/sec_bench/scripts/run_infer.sh llm.eval_claude_3_7 HEAD CodeActAgent 80 $max_iterations $num_workers SEC-bench/SEC-bench $label 1.5
    # ./evaluation/benchmarks/sec_bench/scripts/run_infer.sh llm.eval_gemini-2-5-pro HEAD CodeActAgent 80 $max_iterations $num_workers SEC-bench/SEC-bench $label 1.5
    # ./evaluation/benchmarks/sec_bench/scripts/run_infer.sh llm.eval_gpt_4o HEAD CodeActAgent 80 $max_iterations $num_workers SEC-bench/SEC-bench $label 1.0
    # ./evaluation/benchmarks/sec_bench/scripts/run_infer.sh llm.eval_o3_mini HEAD CodeActAgent 80 $max_iterations $num_workers SEC-bench/SEC-bench $label 1.0
elif [ "$mode" = "eval" ]; then
    poetry run python evaluation/benchmarks/sec_bench/run_eval.py --input-file evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/output.jsonl
    poetry run python evaluation/benchmarks/sec_bench/run_eval.py --input-file evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/output.jsonl
    poetry run python evaluation/benchmarks/sec_bench/run_eval.py --input-file evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-2.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/output.jsonl
    poetry run python evaluation/benchmarks/sec_bench/run_eval.py --input-file evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/o3-mini_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/output.jsonl
elif [ "$mode" = "view" ]; then
    echo -e "\e[1;36mClaude 3.7 Sonnet 20250219\e[0m"
    jq -r '[.instance_id, .success, .reason] | @tsv' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl
    echo -e "--- Statistics ---"

    # Calculate total entries
    TOTAL_CLAUDE=$(jq -r '.reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)

    # Calculate counts
    SUCCESS_CLAUDE=$(jq -r 'select(.reason | contains("Patch applied, compiled, and run successfully.")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    NO_PATCH_CLAUDE=$(jq -r 'select(.reason | contains("No git_patch provided")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    GIT_CLAUDE=$(jq -r 'select(.reason | contains("FAIL_STEP: Git apply")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    COMPILE_CLAUDE=$(jq -r 'select(.reason | contains("FAIL_STEP: Compile")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    FAIL_FIX_CLAUDE=$(jq -r 'select(.reason | contains("FAIL_STEP: Run PoC")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/claude-3-7-sonnet-20250219_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)

    # Calculate percentages
    SUCCESS_PERC_CLAUDE=$(echo "scale=2; $SUCCESS_CLAUDE * 100 / $TOTAL_CLAUDE" | bc)
    NO_PATCH_PERC_CLAUDE=$(echo "scale=2; $NO_PATCH_CLAUDE * 100 / $TOTAL_CLAUDE" | bc)
    GIT_PERC_CLAUDE=$(echo "scale=2; $GIT_CLAUDE * 100 / $TOTAL_CLAUDE" | bc)
    COMPILE_PERC_CLAUDE=$(echo "scale=2; $COMPILE_CLAUDE * 100 / $TOTAL_CLAUDE" | bc)
    FAIL_FIX_PERC_CLAUDE=$(echo "scale=2; $FAIL_FIX_CLAUDE * 100 / $TOTAL_CLAUDE" | bc)

    # Display results
    echo -e "\e[1;32mSuccess: $SUCCESS_CLAUDE/$TOTAL_CLAUDE ($SUCCESS_PERC_CLAUDE%)\e[0m"
    echo "No Patch: $NO_PATCH_CLAUDE/$TOTAL_CLAUDE ($NO_PATCH_PERC_CLAUDE%)"
    echo "Patch Format Error: $GIT_CLAUDE/$TOTAL_CLAUDE ($GIT_PERC_CLAUDE%)"
    echo "Compile Error: $COMPILE_CLAUDE/$TOTAL_CLAUDE ($COMPILE_PERC_CLAUDE%)"
    echo "Fail to Fix: $FAIL_FIX_CLAUDE/$TOTAL_CLAUDE ($FAIL_FIX_PERC_CLAUDE%)"

    echo -e "\n\e[1;36mGPT 4o\e[0m"
    jq -r '[.instance_id, .success, .reason] | @tsv' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl
    echo -e "--- Statistics ---"

    # Calculate total entries
    TOTAL_GPT=$(jq -r '.reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)

    # Calculate counts
    SUCCESS_GPT=$(jq -r 'select(.reason | contains("Patch applied, compiled, and run successfully.")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    NO_PATCH_GPT=$(jq -r 'select(.reason | contains("No git_patch provided")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    GIT_GPT=$(jq -r 'select(.reason | contains("FAIL_STEP: Git apply")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    COMPILE_GPT=$(jq -r 'select(.reason | contains("FAIL_STEP: Compile")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    FAIL_FIX_GPT=$(jq -r 'select(.reason | contains("FAIL_STEP: Run PoC")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gpt-4o_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)

    # Calculate percentages
    SUCCESS_PERC_GPT=$(echo "scale=2; $SUCCESS_GPT * 100 / $TOTAL_GPT" | bc)
    NO_PATCH_PERC_GPT=$(echo "scale=2; $NO_PATCH_GPT * 100 / $TOTAL_GPT" | bc)
    GIT_PERC_GPT=$(echo "scale=2; $GIT_GPT * 100 / $TOTAL_GPT" | bc)
    COMPILE_PERC_GPT=$(echo "scale=2; $COMPILE_GPT * 100 / $TOTAL_GPT" | bc)
    FAIL_FIX_PERC_GPT=$(echo "scale=2; $FAIL_FIX_GPT * 100 / $TOTAL_GPT" | bc)

    # Display results
    echo -e "\e[1;32mSuccess: $SUCCESS_GPT/$TOTAL_GPT ($SUCCESS_PERC_GPT%)\e[0m"
    echo "No Patch: $NO_PATCH_GPT/$TOTAL_GPT ($NO_PATCH_PERC_GPT%)"
    echo "Patch Format Error: $GIT_GPT/$TOTAL_GPT ($GIT_PERC_GPT%)"
    echo "Compile Error: $COMPILE_GPT/$TOTAL_GPT ($COMPILE_PERC_GPT%)"
    echo "Fail to Fix: $FAIL_FIX_GPT/$TOTAL_GPT ($FAIL_FIX_PERC_GPT%)"

    echo -e "\n\e[1;36mGemini 1.5 Pro\e[0m"
    jq -r '[.instance_id, .success, .reason] | @tsv' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl
    echo -e "--- Statistics ---"

    # Calculate total entries
    TOTAL_GEMINI=$(jq -r '.reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)

    # Calculate counts
    SUCCESS_GEMINI=$(jq -r 'select(.reason | contains("Patch applied, compiled, and run successfully.")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    NO_PATCH_GEMINI=$(jq -r 'select(.reason | contains("No git_patch provided")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    GIT_GEMINI=$(jq -r 'select(.reason | contains("FAIL_STEP: Git apply")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    COMPILE_GEMINI=$(jq -r 'select(.reason | contains("FAIL_STEP: Compile")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)
    FAIL_FIX_GEMINI=$(jq -r 'select(.reason | contains("FAIL_STEP: Run PoC")) | .reason' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/gemini-1.5-pro_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl | wc -l)

    # Calculate percentages
    SUCCESS_PERC_GEMINI=$(echo "scale=2; $SUCCESS_GEMINI * 100 / $TOTAL_GEMINI" | bc)
    NO_PATCH_PERC_GEMINI=$(echo "scale=2; $NO_PATCH_GEMINI * 100 / $TOTAL_GEMINI" | bc)
    GIT_PERC_GEMINI=$(echo "scale=2; $GIT_GEMINI * 100 / $TOTAL_GEMINI" | bc)
    COMPILE_PERC_GEMINI=$(echo "scale=2; $COMPILE_GEMINI * 100 / $TOTAL_GEMINI" | bc)
    FAIL_FIX_PERC_GEMINI=$(echo "scale=2; $FAIL_FIX_GEMINI * 100 / $TOTAL_GEMINI" | bc)

    # Display results
    echo -e "\e[1;32mSuccess: $SUCCESS_GEMINI/$TOTAL_GEMINI ($SUCCESS_PERC_GEMINI%)\e[0m"
    echo "No Patch: $NO_PATCH_GEMINI/$TOTAL_GEMINI ($NO_PATCH_PERC_GEMINI%)"
    echo "Patch Format Error: $GIT_GEMINI/$TOTAL_GEMINI ($GIT_PERC_GEMINI%)"
    echo "Compile Error: $COMPILE_GEMINI/$TOTAL_GEMINI ($COMPILE_PERC_GEMINI%)"
    echo "Fail to Fix: $FAIL_FIX_GEMINI/$TOTAL_GEMINI ($FAIL_FIX_PERC_GEMINI%)"
    # echo "--------------------------------"
    # jq -r '[.instance_id, .success, .reason] | @tsv' evaluation/evaluation_outputs/outputs/SEC-bench__SEC-bench-$label/CodeActAgent/o3-mini_maxiter_${max_iterations}_N_v0.29.0-no-hint-run_1/report.jsonl
else
    echo "Invalid mode: $mode"
    echo "Modes: infer, eval"
    exit 1
fi
