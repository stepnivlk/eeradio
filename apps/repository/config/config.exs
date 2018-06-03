use Mix.Config

config :bolt_sips, Bolt,
  hostname: 'localhost',
  basic_auth: [username: System.get_env("NEO_USER"), password: System.get_env("NEO_PASSWORD")],
  port: 7687,
  pool_size: 5,
  max_overflow: 1
