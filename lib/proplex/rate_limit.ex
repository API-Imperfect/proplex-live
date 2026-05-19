defmodule Proplex.RateLimit do
  use Hammer, backend: :ets

  def record_failed_login(email, ip) when is_binary(email) and is_binary(ip) do
    window = :timer.minutes(15)

    with {:allow, _} <- hit("login_fail:email:#{email}", window, 5),
         {:allow, _} <- hit("login_fail:ip:#{ip}", window, 20) do
      :ok
    else
      {:deny, _} = deny -> deny
    end
  end

  def record_reset_request(email, ip) when is_binary(email) and is_binary(ip) do
    window = :timer.hours(1)

    with {:allow, _} <- hit("pw_reset:email:#{email}", window, 3),
         {:allow, _} <- hit("pw_reset:ip:#{ip}", window, 10) do
      :ok
    else
      {:deny, _} = deny -> deny
    end
  end
end
