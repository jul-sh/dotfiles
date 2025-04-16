#!/usr/bin/env zsh

format_command_in_clipboard() {
  read -r -d '' instruction <<'END_OF_INSTRUCTION'
Format the following shell command to be more human-readable. Pay special attention to make sure that the formatted shell command still does the exact same thing as the unformatted one. Respond with only the formatted command, nothing else.

For example, if presented with this command

xtask run -- \
--tk_resource_alloc=project/resource/quota-name \
--experiment_name="Specific Experiment Name" \
--target_model.model_url=model/path/or/identifier \
--target_model.model_type=MODEL_TYPE_A \
--target_model.gemini_tokenizer_type=TOKENIZER_TYPE_X \
--target_model.use_client_side_formatting_and_tokenization=True \
--eval_config.ckpt_dir=/path/to/your/checkpoints \
--eval_jobs=\{\"data_source.data_size\":100,\"data_source.tk_source.xid\":123456789,\"eval_config.prompt_spec_name\":\"your_prompt_spec\",\"eval_config.job_type\":\"your_job_type\",\"eval_config.data_size\":500,\"eval_config.defense_name\":\"your_defense_mechanism\",\"eval_config.defense_args\":\{\}\}

you would output:

xtask run -- \
  --tk_resource_alloc="project/resource/quota-name" \
  --experiment_name="Specific Experiment Name" \
  --target_model.model_url="model/path/or/identifier" \
  --target_model.model_type="MODEL_TYPE_A" \
  --target_model.gemini_tokenizer_type="TOKENIZER_TYPE_X" \
  --target_model.use_client_side_formatting_and_tokenization="True" \
  --eval_config.ckpt_dir="/path/to/your/checkpoints" \
  --eval_jobs='{
    "data_source.data_size": 100,
    "data_source.tk_source.xid": 123456789,
    "eval_config.prompt_spec_name": "your_prompt_spec",
    "eval_config.job_type": "your_job_type",
    "eval_config.data_size": 500,
    "eval_config.defense_name": "your_defense_mechanism",
    "eval_config.defense_args": {}
  }'

Respond with only the raw formatted command, nothing else.
END_OF_INSTRUCTION

  echo "✨ started formatting"

  pbpaste | aichat "$instruction" | sed -e 's/^```bash[[:space:]]*//' -e 's/[[:space:]]*```$//' | pbcopy

  echo "✨ finished formatting"
}
