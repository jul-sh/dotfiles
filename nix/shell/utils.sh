#!/usr/bin/env zsh

format_command_in_clipboard() {
  read -r -d '' instruction <<'END_OF_INSTRUCTION'
Format the following shell command to be more human-readable. Pay special attention to make sure that the formatted shell command still does the exact same thing as the unformatted one. Respond with only the formatted command, nothing else.

For example, if presented with this command

xtask run -- \
--tk_parent=project/resource/quota-name \
--experiment_name="Specific Experiment Name" \
--target_item.item_location=item/path/or/identifier \
--target_item.item_category=CATEGORY_A \
--target_item.processing_mode=MODE_X \
--target_item.use_client_side_processing=True \
--run_config.output_dir=/path/to/your/output \
--run_params=\{\"data_source.data_size\":100,\"data_source.tk_source.grl\":123456789,\"run_config.spec_name\":\"your_spec\",\"run_config.task_type\":\"your_task_type\",\"run_config.item_count\":500,\"run_config.bear_mechanism\":\"your_bear_mechanism\",\"run_config.bear_args\":\{\}\}

you would output:

xtask run -- \
  --tk_parent="project/resource/quota-name" \
  --experiment_name="Specific Experiment Name" \
  --target_item.item_location="item/path/or/identifier" \
  --target_item.item_category="CATEGORY_A" \
  --target_item.processing_mode="MODE_X" \
  --target_item.use_client_side_processing="True" \
  --run_config.output_dir="/path/to/your/output" \
  --run_params='{
    "data_source.data_size": 100,
    "data_source.tk_source.grl": 123456789,
    "run_config.spec_name": "your_spec",
    "run_config.task_type": "your_task_type",
    "run_config.item_count": 500,
    "run_config.bear_mechanism": "your_bear_mechanism",
    "run_config.bear_args": {}
  }'

Respond with only the raw formatted command, nothing else.
END_OF_INSTRUCTION

  echo "✨ started formatting"

  pbpaste | @aichat@ "$instruction" | sed -e 's/^```bash[[:space:]]*//' -e 's/[[:space:]]*```$//' | pbcopy

  echo "✨ finished formatting"
}
