defmodule App.Storage.Mongo do
  @behaviour App.StorageIntf
  alias App.Devices.Device

  def save(%Device{} = device) do
    Mongo.replace_one(:mongo, "devices", %{device_id: device.device_id}, Map.from_struct(device), upsert: true)
  end

  def get(device_id) do
    case Mongo.find_one(:mongo, "devices", %{device_id: device_id}) do
      nil -> nil
      doc -> struct(Device, doc)
    end
  end

  def delete(device_id), do: Mongo.delete_one(:mongo, "devices", %{device_id: device_id})
  def all_by_user(eid), do: Mongo.find(:mongo, "devices", %{eid: eid}) |> Enum.map(&struct(Device, &1))
end
