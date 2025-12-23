{
  # Default (empty) local host configuration.
  # This is overridden at runtime by setup.sh via --override-input
  outputs = { ... }: {
    homeModules.default = { ... }: { };
  };
}
