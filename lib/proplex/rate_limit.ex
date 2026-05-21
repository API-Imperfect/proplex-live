defmodule Proplex.RateLimit do
  use Hammer, backend: :ets
  require Logger

  def record_failed_login(email, ip) when is_binary(email) and is_binary(ip) do
    window = :timer.minutes(15)

    with {:allow, _} <- hit("login_fail:email:#{email}", window, 5),
         {:allow, _} <- hit("login_fail:ip:#{ip}", window, 20) do
      :ok
    else
      {:deny, retry_after_ms} ->
        Logger.warning("Failed-login rate limit exceeded",
          event: :rate_limit_denied,
          limiter: :failed_login,
          email: email,
          ip: ip,
          retry_after_ms: retry_after_ms
        )

        {:deny, retry_after_ms}
    end
  end

  def record_reset_request(email, ip) when is_binary(email) and is_binary(ip) do
    window = :timer.hours(1)

    with {:allow, _} <- hit("pw_reset:email:#{email}", window, 3),
         {:allow, _} <- hit("pw_reset:ip:#{ip}", window, 10) do
      :ok
    else
      {:deny, retry_after_ms} ->
        Logger.warning("Password-reset rate limit exceeded",
          event: :rate_limit_denied,
          limiter: :password_reset,
          email: email,
          ip: ip,
          retry_after_ms: retry_after_ms
        )

        {:deny, retry_after_ms}
    end
  end
end
