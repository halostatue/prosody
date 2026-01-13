ExUnit.start(capture_log: true, timeout: 1_000)

Application.put_env(:tableau, :config, url: "http://localhost")
