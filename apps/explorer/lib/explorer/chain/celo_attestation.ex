defmodule Explorer.Chain.CeloAttestation do
  @moduledoc """
  Data type and schema for signer history for accounts
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - address of the validator.
  *
  """

  @type t :: %__MODULE__{
          attestor_hash: Hash.Address.t(),
          attestee_hash: Hash.Address.t(),
          status: String.t(),
          block_number: integer,
          identifier: String.t()
        }

  @attrs ~w(
        attestor_hash attestee_hash identifier status block_number
      )a

  @required_attrs ~w(
        attestor_hash attestee_hash identifier status block_number
      )a

  schema "celo_attestations" do
    belongs_to(
      :attestor,
      Address,
      foreign_key: :attestor_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :attestee,
      Address,
      foreign_key: :attestee_hash,
      references: :hash,
      type: Hash.Address
    )

    field(:status, :string)
    field(:block_number, :integer)
    field(:identifier, :string)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_signers, attrs) do
    celo_signers
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_attestation_key, name: :celo_attestations_attestor_attestee_identifier_index)
  end
end
