defmodule Explorer.Validator.MetadataImporter do
  @moduledoc """
  module that upserts validator metadata from a list of maps
  """
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  def import_metadata(metadata_maps) do
    # Enforce Name ShareLocks order (see docs: sharelocks.md)
    ordered_metadata_maps = Enum.sort_by(metadata_maps, &{&1.address_hash, &1.name})

    Repo.transaction(fn -> Enum.each(ordered_metadata_maps, &upsert_validator_metadata(&1)) end)
  end

  defp upsert_validator_metadata(_validator_changeset) do
  end
end
