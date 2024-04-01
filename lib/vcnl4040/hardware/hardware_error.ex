defmodule VCNL4040.Hardware.HardwareError do
  defexception [:message, :protocol, :detail, :call, :reason]

  alias VCNL4040.Hardware.HardwareError

  @impl true
  def exception(%{protocol: protocol, detail: detail, call: call, reason: reason}) do
    msg = "Hardware error on #{protocol} #{detail} attempt to #{call} failed: #{reason}"
    %HardwareError{message: msg, protocol: protocol, detail: detail, call: call, reason: reason}
  end

  def exception(value) do
    msg = "General Hardware error: #{inspect(value)}"
    %HardwareError{message: msg}
  end
end
