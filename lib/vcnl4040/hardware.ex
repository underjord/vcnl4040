defmodule VCNL4040.Hardware do
  alias Circuits.I2C
  @expected_device_addr 0x60
  @expected_device_id <<0x86, 0x01>>
  @device_interrupt_register <<0x0B>>
  @ps_data_register 0x08
  @als_data_register 0x09
  @device_id_register <<0x0C>>

  def open(i2c_bus) do
    I2C.open(i2c_bus)
  end

  def is_valid?(bus_ref) do
    case I2C.write_read(bus_ref, @expected_device_addr, @device_id_register, 2) do
      {:ok, dev_id} ->
        dev_id == @expected_device_id

      _ ->
        false
    end
  end

  def write_register(bus_ref, register_data) do
    I2C.write!(bus_ref, @expected_device_addr, register_data)
  end

  def read_ambient_light(bus_ref) do
    <<raw_als_value::little-16>> =
      I2C.write_read!(bus_ref, @expected_device_addr, <<@als_data_register>>, 2)

    raw_als_value
  end

  def read_proximity(bus_ref) do
    <<prox_reading::little-16>> =
      I2C.write_read!(bus_ref, @expected_device_addr, <<@ps_data_register>>, 2)

    prox_reading
  end

  def apply_device_config(registers, bus_ref) when is_list(registers) do
    Enum.each(registers, fn register_data ->
      write_register(bus_ref, register_data)
    end)
  end

  def setup_interrupts(pin) do
    case Circuits.GPIO.open(pin, :input, pullmode: :pullup) do
      {:ok, interrupt_ref} ->
        case Circuits.GPIO.set_interrupts(interrupt_ref, :both) do
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
    I2C.write_read!(bus_ref, @expected_device_addr, <<@device_interrupt_register>>, 2)
  end
end
