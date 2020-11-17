defmodule WalletApi.TransactionResolverTest do
  use WalletApi.ConnCase
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  setup do
    Supervisor.terminate_child(WalletApi.Supervisor, {ConCache, :exchange_rate_cache})
    Supervisor.restart_child(WalletApi.Supervisor, {ConCache, :exchange_rate_cache})
    Supervisor.terminate_child(WalletApi.Supervisor, {ConCache, :contract_address_cache})
    Supervisor.restart_child(WalletApi.Supervisor, {ConCache, :contract_address_cache})
    :ok
  end

  @transaction_data [
    %{
      block_number: 90608,
      celo_transfer: [
        %{
          from_address_hash: "0x6a61e1e693c765cbab7e02a500665f2e13ee46df",
          to_address_hash: "0x0000000000000000000000000000000000007E57",
          token: "cGLD",
          value: Decimal.new(1_000_000_000_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xf1235cb0d3703e7cc2473fb4e214fbc7a9ff77cc",
          token: "cUSD",
          value: Decimal.new(10_000_000_000_000_000_000)
        },
        %{
          from_address_hash: "0xf1235cb0d3703e7cc2473fb4e214fbc7a9ff77cc",
          to_address_hash: "0x0000000000000000000000000000000000000000",
          token: "cUSD",
          value: Decimal.new(10_000_000_000_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xa12a699c641cc875a7ca57495861c79c33d293b4",
          token: "cUSD",
          value: Decimal.new(1_991_590_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xdd1f519f63423045f526b8c83edc0eb4ba6434a4",
          token: "cUSD",
          value: Decimal.new(7_966_360_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xf9720b2ff2cf69f8a50dc5bec5545ba883e0ae3f",
          token: "cUSD",
          value: Decimal.new(0)
        }
      ],
      fee_currency: "0xa561131a1c8ac25925fb848bca45a74af61e5a38",
      fee_token: "cUSD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(50_000_000_000)},
      gas_used: Decimal.new(199_159),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: "0xf9720b2ff2cf69f8a50dc5bec5545ba883e0ae3f",
      timestamp: ~U[2019-08-21 00:03:17.000000Z],
      transaction_hash: "0xba620de2d812f299d987155eb5dca7abcfeaf154f5cfd99cb1773452a7df3d7a"
    },
    # Exchange cGLD -> cUSD
    %{
      block_number: 90637,
      celo_transfer: [
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x6a61e1e693c765cbab7e02a500665f2e13ee46df",
          token: "cGLD",
          value: Decimal.new(1_000_000_000_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000000000",
          to_address_hash: "0x0000000000000000000000000000000000007E57",
          token: "cUSD",
          value: Decimal.new(10_000_000_000_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xa12a699c641cc875a7ca57495861c79c33d293b4",
          token: "cUSD",
          value: Decimal.new(2_175_980_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x30d060f129817c4de5fbc1366d53e19f43c8c64f",
          token: "cUSD",
          value: Decimal.new(8_703_920_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xfcf7fc2f0c1f06fb6314f9fa2a53e9805aa863e0",
          token: "cUSD",
          value: Decimal.new(0)
        }
      ],
      fee_currency: "0xa561131a1c8ac25925fb848bca45a74af61e5a38",
      fee_token: "cUSD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(50_000_000_000)},
      gas_used: Decimal.new(217_598),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: "0xfcf7fc2f0c1f06fb6314f9fa2a53e9805aa863e0",
      timestamp: ~U[2019-08-21 00:04:26.000000Z],
      transaction_hash: "0x961403536006f9c120c23900f94da59dbf43edf10eb3569b448665483bab77b2"
    },
    # Dollars sent
    %{
      block_number: 90719,
      celo_transfer: [
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x8b7649116f169d2d2aebb6ea1a77f0baf31f2811",
          token: "cUSD",
          value: Decimal.new(150_000_000_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xa12a699c641cc875a7ca57495861c79c33d293b4",
          token: "cUSD",
          value: Decimal.new(1_131_780_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x050f34537f5b2a00b9b9c752cb8500a3fce3da7d",
          token: "cUSD",
          value: Decimal.new(4_527_120_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x6a0edf42f5e618bee697e7718fa05efb1ea5d11c",
          token: "cUSD",
          value: Decimal.new(0)
        }
      ],
      fee_currency: "0xa561131a1c8ac25925fb848bca45a74af61e5a38",
      fee_token: "cUSD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(50_000_000_000)},
      gas_used: Decimal.new(113_178),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: "0x6a0edf42f5e618bee697e7718fa05efb1ea5d11c",
      timestamp: ~U[2019-08-21 00:11:16.000000Z],
      transaction_hash: "0x21dd2c18ae6c80d61ffbddaa073f7cde7bbfe9436fdf5059b506f1686326a2fb"
    },
    # Dollars received
    %{
      block_number: 117_453,
      celo_transfer: [
        %{
          from_address_hash: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
          to_address_hash: "0x0000000000000000000000000000000000007E57",
          token: "cUSD",
          value: Decimal.new(10_000_000_000_000_000_000)
        },
        %{
          from_address_hash: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
          to_address_hash: "0xa12a699c641cc875a7ca57495861c79c33d293b4",
          token: "cUSD",
          value: Decimal.new(1_297_230_000_000_000)
        },
        %{
          from_address_hash: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
          to_address_hash: "0x2a43f97f8bf959e31f69a894ebd80a88572c8553",
          token: "cUSD",
          value: Decimal.new(5_188_920_000_000_000)
        },
        %{
          from_address_hash: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
          to_address_hash: "0xfcf7fc2f0c1f06fb6314f9fa2a53e9805aa863e0",
          token: "cUSD",
          value: Decimal.new(0)
        }
      ],
      fee_currency: "0xa561131a1c8ac25925fb848bca45a74af61e5a38",
      fee_token: "cUSD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(50_000_000_000)},
      gas_used: Decimal.new(129_723),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: "0xfcf7fc2f0c1f06fb6314f9fa2a53e9805aa863e0",
      timestamp: ~U[2019-08-22 13:19:06.000000Z],
      transaction_hash: "0xe70bf600802bae7a0d42d89d54b8cdb977a8c5a34a239ec73597c7abcab74536"
    },
    # Gold sent
    %{
      block_number: 117_451,
      celo_transfer: [
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
          token: "cGLD",
          value: Decimal.new(1_000_000_000_000_000_000)
        }
      ],
      fee_currency: nil,
      fee_token: "cGLD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(5_000_000_000)},
      gas_used: Decimal.new(47426),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: nil,
      timestamp: ~U[2019-08-22 13:36:40.000000Z],
      transaction_hash: "0xc6689ed516e8b114e875d682bbf7ba318ea16841711d97ce473f20da289435be"
    },
    # Gold received
    %{
      block_number: 117_451,
      celo_transfer: [
        %{
          from_address_hash: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
          to_address_hash: "0x0000000000000000000000000000000000007E57",
          token: "cGLD",
          value: Decimal.new(10_000_000_000_000_000_000)
        }
      ],
      fee_currency: nil,
      fee_token: "cGLD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(5_000_000_000)},
      gas_used: Decimal.new(47426),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: nil,
      timestamp: ~U[2019-08-22 13:53:20.000000Z],
      transaction_hash: "0xe8fe81f455eb34b672a8d8dd091472f1ae8d4d204817f0bcbb7a13486b9b5605"
    },
    # Faucet received
    %{
      block_number: 117_451,
      celo_transfer: [
        %{
          from_address_hash: "0x456f41406B32c45D59E539e4BBA3D7898c3584dA",
          to_address_hash: "0x0000000000000000000000000000000000007E57",
          token: "cGLD",
          value: Decimal.new(5_000_000_000_000_000_000)
        }
      ],
      fee_currency: nil,
      fee_token: "cGLD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(5_000_000_000)},
      gas_used: Decimal.new(47426),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: nil,
      timestamp: ~U[2019-08-22 14:10:00.000000Z],
      transaction_hash: "0xf6856169eb7bf78211babc312028cddf3dad2761799428ab6e4fcf297a27fe09"
    },
    # Verification fee sent (no gateway fee recipient)
    %{
      block_number: 117_451,
      celo_transfer: [
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xad5e5722427d79dff28a4ab30249729d1f8b4cc0",
          token: "cUSD",
          value: Decimal.new(200_000_000_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xa12a699c641cc875a7ca57495861c79c33d293b4",
          token: "cUSD",
          value: Decimal.new(1_590_510_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xae1ec841923811219b98aceb1db297aade2f46f3",
          token: "cUSD",
          value: Decimal.new(6_362_040_000_000_000)
        }
      ],
      fee_currency: "0xa561131a1c8ac25925fb848bca45a74af61e5a38",
      fee_token: "cUSD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(50_000_000_000)},
      gas_used: Decimal.new(159_051),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: nil,
      timestamp: ~U[2019-08-22 14:26:40.000000Z],
      transaction_hash: "0xcc2120e5d050fd68284dc01f6464b2ed8f7358ca80fccb20967af28eb7d79160"
    },
    # Contract call with no true token transfers (just fees)
    %{
      block_number: 192_467,
      celo_transfer: [
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0xa12a699c641cc875a7ca57495861c79c33d293b4",
          token: "cUSD",
          value: Decimal.new(990_330_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x456f41406b32c45d59e539e4bba3d7898c3584da",
          token: "cUSD",
          value: Decimal.new(3_961_320_000_000_000)
        },
        %{
          from_address_hash: "0x0000000000000000000000000000000000007E57",
          to_address_hash: "0x6a0edf42f5e618bee697e7718fa05efb1ea5d11c",
          token: "cUSD",
          value: Decimal.new(0)
        }
      ],
      fee_currency: "0xa561131a1c8ac25925fb848bca45a74af61e5a38",
      fee_token: "cUSD",
      gas_price: %Explorer.Chain.Wei{value: Decimal.new(50_000_000_000)},
      gas_used: Decimal.new(99033),
      gateway_fee: %Explorer.Chain.Wei{value: Decimal.new(0)},
      gateway_fee_recipient: "0x6a0edf42f5e618bee697e7718fa05efb1ea5d11c",
      timestamp: ~U[2020-04-21 09:29:44.000000Z],
      transaction_hash: "0xfa658a2be84e9ef0ead58ea2d8e2d3c9160bf0769451b5dc971c2d82c9c33c42"
    }
  ]

  describe "transactionResolver" do
    test "should get dollar transaction and label them properly" do

      GetTransactionBehaviorMock
      |> expect(:get_transaction_data, fn _args ->
        @transaction_data
      end)

      args = %{
        :address => "0x0000000000000000000000000000000000007E57",
        :local_currency_code => "MXN",
        :token => "cUSD"
      }

      expected_output = %{
        edges: [
          %{
            cursor: "TODO",
            node: %{
              address: "0xad5e5722427d79dff28a4ab30249729d1f8b4cc0",
              amount: %{
                currency_code: "cUSD",
                timestamp: 1_566_484_000_000,
                value: Decimal.new(-0.2)
              },
              block: 117_451,
              comment: "",
              hash: "0xcc2120e5d050fd68284dc01f6464b2ed8f7358ca80fccb20967af28eb7d79160",
              timestamp: 1_566_484_000_000,
              type: :verification_fee
            }
          },
          %{
            cursor: "TODO",
            node: %{
              address: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
              amount: %{
                currency_code: "cUSD",
                timestamp: 1_566_479_946_000,
                value: Decimal.new(10)
              },
              block: 117_453,
              comment: "",
              hash: "0xe70bf600802bae7a0d42d89d54b8cdb977a8c5a34a239ec73597c7abcab74536",
              timestamp: 1_566_479_946_000,
              type: :received
            }
          },
          %{
            cursor: "TODO",
            node: %{
              address: "0x8b7649116f169d2d2aebb6ea1a77f0baf31f2811",
              amount: %{
                currency_code: "cUSD",
                timestamp: 1_566_346_276_000,
                value: Decimal.new(-0.15)
              },
              block: 90719,
              comment: "",
              hash: "0x21dd2c18ae6c80d61ffbddaa073f7cde7bbfe9436fdf5059b506f1686326a2fb",
              timestamp: 1_566_346_276_000,
              type: :sent
            }
          },
          %{
            cursor: "TODO",
            node: %{
              amount: %{
                currency_code: "cUSD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_866_000,
                value: Decimal.new(10)
              },
              block: 90637,
              hash: "0x961403536006f9c120c23900f94da59dbf43edf10eb3569b448665483bab77b2",
              maker_amount: %{
                currency_code: "cGLD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_866_000,
                value: Decimal.new(1)
              },
              taker_amount: %{
                currency_code: "cUSD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_866_000,
                value: Decimal.new(10)
              },
              timestamp: 1_566_345_866_000,
              type: :exchange
            }
          },
          %{
            cursor: "TODO",
            node: %{
              amount: %{
                currency_code: "cUSD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_797_000,
                value: Decimal.new(-10)
              },
              block: 90608,
              hash: "0xba620de2d812f299d987155eb5dca7abcfeaf154f5cfd99cb1773452a7df3d7a",
              maker_amount: %{
                currency_code: "cUSD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_797_000,
                value: Decimal.new(10)
              },
              taker_amount: %{
                currency_code: "cGLD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_797_000,
                value: Decimal.new(1)
              },
              timestamp: 1_566_345_797_000,
              type: :exchange
            }
          }
        ],
        page_info: %{
          end_cursor: "TODO",
          has_next_page: false,
          has_previous_page: false,
          start_cursor: "TODO"
        }
      }

      {:ok, response} = WalletApi.Resolver.get_token_transactions(0, args, 0)
      assert Map.equal?(response, expected_output)
    end

    test "should get gold transaction and label them properly" do

      GetTransactionBehaviorMock
      |> expect(:get_transaction_data, fn _args ->
        @transaction_data
      end)

      args = %{
        :address => "0x0000000000000000000000000000000000007E57",
        :local_currency_code => "MXN",
        :token => "cGLD"
      }

      expected_output = %{
        edges: [
          %{
            cursor: "TODO",
            node: %{
              address: "0x456f41406B32c45D59E539e4BBA3D7898c3584dA",
              amount: %{
                currency_code: "cGLD",
                timestamp: 1_566_483_000_000,
                value: Decimal.new(5)
              },
              block: 117_451,
              comment: "",
              hash: "0xf6856169eb7bf78211babc312028cddf3dad2761799428ab6e4fcf297a27fe09",
              timestamp: 1_566_483_000_000,
              type: :faucet
            }
          },
          %{
            cursor: "TODO",
            node: %{
              address: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
              amount: %{
                currency_code: "cGLD",
                timestamp: 1_566_482_000_000,
                value: Decimal.new(10)
              },
              block: 117_451,
              comment: "",
              hash: "0xe8fe81f455eb34b672a8d8dd091472f1ae8d4d204817f0bcbb7a13486b9b5605",
              timestamp: 1_566_482_000_000,
              type: :received
            }
          },
          %{
            cursor: "TODO",
            node: %{
              address: "0xf4314cb9046bece6aa54bb9533155434d0c76909",
              amount: %{
                currency_code: "cGLD",
                timestamp: 1_566_481_000_000,
                value: Decimal.new(-1)
              },
              block: 117_451,
              comment: "",
              hash: "0xc6689ed516e8b114e875d682bbf7ba318ea16841711d97ce473f20da289435be",
              timestamp: 1_566_481_000_000,
              type: :sent
            }
          },
          %{
            cursor: "TODO",
            node: %{
              amount: %{
                currency_code: "cGLD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_866_000,
                value: Decimal.new(-1)
              },
              block: 90637,
              hash: "0x961403536006f9c120c23900f94da59dbf43edf10eb3569b448665483bab77b2",
              maker_amount: %{
                currency_code: "cGLD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_866_000,
                value: Decimal.new(1)
              },
              taker_amount: %{
                currency_code: "cUSD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_866_000,
                value: Decimal.new(10)
              },
              timestamp: 1_566_345_866_000,
              type: :exchange
            }
          },
          %{
            cursor: "TODO",
            node: %{
              amount: %{
                currency_code: "cGLD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_797_000,
                value: Decimal.new(1)
              },
              block: 90608,
              hash: "0xba620de2d812f299d987155eb5dca7abcfeaf154f5cfd99cb1773452a7df3d7a",
              maker_amount: %{
                currency_code: "cUSD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_797_000,
                value: Decimal.new(10)
              },
              taker_amount: %{
                currency_code: "cGLD",
                implied_exchange_rates: %{"cGLD/cUSD" => Decimal.new(10)},
                timestamp: 1_566_345_797_000,
                value: Decimal.new(1)
              },
              timestamp: 1_566_345_797_000,
              type: :exchange
            }
          }
        ],
        page_info: %{
          end_cursor: "TODO",
          has_next_page: false,
          has_previous_page: false,
          start_cursor: "TODO"
        }
      }

      {:ok, response} = WalletApi.Resolver.get_token_transactions(0, args, 0)
      assert Map.equal?(response, expected_output)
    end

    test "should get correct response for graphql queries", %{conn: conn} do
      IO.inspect(conn)
      GetTransactionBehaviorMock
      |> expect(:get_transaction_data, fn _args ->
        @transaction_data
      end)

      query = """
      query token_transactions($address: Address!, $token: Token!, $localCurrencyCode: String) {
          token_transactions(address: $address, token: $token, localCurrencyCode: $localCurrencyCode) {
            edges {
              node {
                type
                timestamp
                block
                hash
                amount{
                  value
                  currency_code
                  local_amount{
                    value
                    exchange_rate
                    currency_code
                  }
                }
                ... on TokenTransfer{
                  comment
                  address
                }

                ... on TokenExchange{
                  takerAmount{
                    value
                    currency_code
                    local_amount{
                      value
                      currency_code
                      exchange_rate
                    }
                  }
                  maker_amount{
                    value
                    currency_code
                    local_amount{
                      value
                      currency_code
                      exchange_rate
                    }
                  }
                }
              }
              cursor
            }
            pageInfo {
              hasPreviousPage
              hasNextPage
            }
          }
        }
      """

      variables = %{
        "address" => "0x0000000000000000000000000000000000007E57",
        "token" => "cUSD",
        "localCurrencyCode" => "USD"
      }

      conn = get(conn, "/walletapi", query: query, variables: variables)

      expected_output = %{
        "data" => %{
          "token_transactions" => %{
            "edges" => [
              %{
                "cursor" => "TODO",
                "node" => %{
                  "address" => "0xad5e5722427d79dff28a4ab30249729d1f8b4cc0",
                  "amount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "-0.20"
                    },
                    "value" => "-0.2"
                  },
                  "block" => "117451",
                  "comment" => "",
                  "hash" => "0xcc2120e5d050fd68284dc01f6464b2ed8f7358ca80fccb20967af28eb7d79160",
                  "timestamp" => 1_566_484_000_000,
                  "type" => "VERIFICATION_FEE"
                }
              },
              %{
                "cursor" => "TODO",
                "node" => %{
                  "address" => "0xf4314cb9046bece6aa54bb9533155434d0c76909",
                  "amount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "10.0"
                    },
                    "value" => "10"
                  },
                  "block" => "117453",
                  "comment" => "",
                  "hash" => "0xe70bf600802bae7a0d42d89d54b8cdb977a8c5a34a239ec73597c7abcab74536",
                  "timestamp" => 1_566_479_946_000,
                  "type" => "RECEIVED"
                }
              },
              %{
                "cursor" => "TODO",
                "node" => %{
                  "address" => "0x8b7649116f169d2d2aebb6ea1a77f0baf31f2811",
                  "amount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "-0.150"
                    },
                    "value" => "-0.15"
                  },
                  "block" => "90719",
                  "comment" => "",
                  "hash" => "0x21dd2c18ae6c80d61ffbddaa073f7cde7bbfe9436fdf5059b506f1686326a2fb",
                  "timestamp" => 1_566_346_276_000,
                  "type" => "SENT"
                }
              },
              %{
                "cursor" => "TODO",
                "node" => %{
                  "amount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "10.0"
                    },
                    "value" => "10"
                  },
                  "block" => "90637",
                  "hash" => "0x961403536006f9c120c23900f94da59dbf43edf10eb3569b448665483bab77b2",
                  "maker_amount" => %{
                    "currency_code" => "cGLD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "10.0",
                      "value" => "10.0"
                    },
                    "value" => "1"
                  },
                  "takerAmount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "10.0"
                    },
                    "value" => "10"
                  },
                  "timestamp" => 1_566_345_866_000,
                  "type" => "EXCHANGE"
                }
              },
              %{
                "cursor" => "TODO",
                "node" => %{
                  "amount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "-10.0"
                    },
                    "value" => "-10"
                  },
                  "block" => "90608",
                  "hash" => "0xba620de2d812f299d987155eb5dca7abcfeaf154f5cfd99cb1773452a7df3d7a",
                  "maker_amount" => %{
                    "currency_code" => "cUSD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "1.0",
                      "value" => "10.0"
                    },
                    "value" => "10"
                  },
                  "takerAmount" => %{
                    "currency_code" => "cGLD",
                    "local_amount" => %{
                      "currency_code" => "USD",
                      "exchange_rate" => "10.0",
                      "value" => "10.0"
                    },
                    "value" => "1"
                  },
                  "timestamp" => 1_566_345_797_000,
                  "type" => "EXCHANGE"
                }
              }
            ],
            "pageInfo" => %{
              "hasNextPage" => false,
              "hasPreviousPage" => false
            }
          }
        }
      }

      assert Map.equal?(json_response(conn, 200), expected_output)
    end
  end
end
