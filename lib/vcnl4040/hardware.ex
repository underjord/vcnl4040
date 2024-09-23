defmodule VCNL4040.Hardware do
  @moduledoc false

  alias Circuits.I2C
  alias Circuits.GPIO
  alias VCNL4040.Hardware.HardwareError

  @expected_device_addr 0x60
  @expected_device_id <<0x86, 0x01>>
  @device_interrupt_register <<0x0B>>
  @ps_data_register 0x08
  @als_data_register 0x09
  @device_id_register <<0x0C>>

  def open(i2c_bus, retries) do
    I2C.open(i2c_bus, retries: retries)
  end

  def is_valid?(bus_ref) do
    case I2C.write_read(bus_ref, @expected_device_addr, @device_id_register, 2) do
      {:ok, dev_id} ->
        dev_id == @expected_device_id

      _ ->
        false
    end
  end

  defp hexed(v), do: inspect(v, base: :hex)

  def write_register(bus_ref, register_data) do
    case I2C.write(bus_ref, @expected_device_addr, register_data) do
      :ok ->
        :ok

      {:error, reason} ->
        raise HardwareError, %{
          protocol: :i2c,
          detail: hexed(register_data),
          call: :write_register,
          reason: reason
        }
    end
  end

  def read_ambient_light(bus_ref) do
    case I2C.write_read(bus_ref, @expected_device_addr, <<@als_data_register>>, 2) do
      {:ok, <<raw_als_value::little-16>>} ->
        raw_als_value

      {:ok, _} ->
        raise HardwareError, %{
          protocol: :i2c,
          detail: hexed(@als_data_register),
          call: :read_ambient_light,
          reason: :bad_data_in_read
        }

      {:error, reason} ->
        raise HardwareError, %{
          protocol: :i2c,
          detail: hexed(@als_data_register),
          call: :write_register,
          reason: reason
        }
    end
  end

  def read_proximity(bus_ref) do
    case I2C.write_read(bus_ref, @expected_device_addr, <<@ps_data_register>>, 2) do
      {:ok, <<prox_reading::little-16>>} ->
        prox_reading

      {:ok, _} ->
        raise HardwareError, %{
          protocol: :i2c,
          detail: hexed(@ps_data_register),
          call: :read_proximity,
          reason: :bad_data_in_read
        }

      {:error, reason} ->
        raise HardwareError, %{
          protocol: :i2c,
          detail: hexed(@als_data_register),
          call: :write_register,
          reason: reason
        }
    end
  end

  def apply_device_config(registers, bus_ref) when is_list(registers) do
    Enum.each(registers, fn register_data ->
      write_register(bus_ref, register_data)
    end)
  end

  def setup_interrupts(pin) do
    case GPIO.open(pin, :input, pull_mode: :pullup) do
      {:ok, interrupt_ref} ->
        case GPIO.set_interrupts(interrupt_ref, :both) do
          :ok ->
            {:ok, interrupt_ref}

          {:error, reason} ->
            {:error, {:set_interrupts_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:open_failed, reason}}
    end
  end

  def clear_interrupts(bus_ref) do
    case I2C.write_read(bus_ref, @expected_device_addr, <<@device_interrupt_register>>, 2) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        raise HardwareError, %{
          protocol: :i2c,
          detail: hexed(@device_interrupt_register),
          call: :clear_interrupts,
          reason: reason
        }
    end
  end

  def close(bus_ref, interrupt_ref) do
    try do
      I2C.close(bus_ref)
    rescue
      _ ->
        :ignore
    end

    try do
      GPIO.close(interrupt_ref)
    rescue
      _ ->
        :ignore
    end
  end
end
