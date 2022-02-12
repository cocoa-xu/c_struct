defmodule CStruct.Nif do
  @moduledoc false

  @on_load :load_nif
  def load_nif do
    nif_file = '#{:code.priv_dir(:c_struct)}/c_struct_nif'

    case :erlang.load_nif(nif_file, 0) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok
      {:error, reason} -> IO.puts("Failed to load nif: #{reason}")
    end
  end

  def to_binary(_ir), do: :erlang.nif_error(:not_loaded)
end
