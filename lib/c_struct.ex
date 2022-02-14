defmodule CStruct do
  @moduledoc """
  Convert elixir Maps/Keyword List/Custom Module data to C structs
  """

  @doc """
  Convert elixir Maps/Keyword List/Custom Module data to C structs

  ## Examples
  ### Keyword List

      iex> data = [val: 1]
      [val: 1]
      iex> attributes = [specs: [val: %{type: :u32}], alignas: 1, pack: 1]
      [specs: [val: %{type: :u32}], alignas: 1, pack: 1]
      iex> CStruct.to_c_struct(data, attributes)
      <<1, 0, 0, 0>>

  ### Map
      iex> data = %{val: 1}
      %{val: 1}
      iex> attributes = [specs: [val: %{type: :u32, endianness: :big}], alignas: 1, pack: 1]
      [specs: [val: %{type: :u32, endianness: :big}], alignas: 1, pack: 1]
      iex> CStruct.to_c_struct(data, attributes)
      <<0, 0, 0, 1>>
  """
  def to_c_struct(data, attributes, opts \\ [])

  def to_c_struct(keyword_list, attributes, opts)
      when is_list(keyword_list) and is_list(attributes) do
    allow_missing = Keyword.get(opts, :allow_missing, false)
    allow_extra = Keyword.get(opts, :allow_extra, false)
    default_endianness = Keyword.get(opts, :default_endianness, :little)
    ir_only = Keyword.get(opts, :ir_only, false)

    with {:error, reason} <-
           _to_c_struct(
             Keyword,
             keyword_list,
             attributes,
             allow_missing,
             allow_extra,
             default_endianness,
             Keyword.keyword?(keyword_list),
             Keyword.keyword?(attributes)
           ) do
      {:error, reason}
    else
      ir ->
        if ir_only do
          ir
        else
          {layout, struct_size} = CStruct.memory_layout(attributes)
          {CStruct.Nif.to_binary(ir, layout, struct_size), ir, layout, struct_size}
        end
    end
  end

  def to_c_struct(map_data, attributes, opts)
      when is_map(map_data) and is_list(attributes) do
    allow_missing = Keyword.get(opts, :allow_missing, false)
    allow_extra = Keyword.get(opts, :allow_extra, false)
    default_endianness = Keyword.get(opts, :default_endianness, :little)
    ir_only = Keyword.get(opts, :ir_only, false)

    with {:error, reason} <-
           _to_c_struct(
             Map,
             map_data,
             attributes,
             allow_missing,
             allow_extra,
             default_endianness,
             true,
             Keyword.keyword?(attributes)
           ) do
      {:error, reason}
    else
      ir ->
        if ir_only do
          ir
        else
          {layout, struct_size} = CStruct.memory_layout(attributes)
          {CStruct.Nif.to_binary(ir, layout, struct_size), ir, layout, struct_size}
        end
    end
  end

  def to_c_struct(module, data, attributes, opts) when is_list(attributes) and is_list(opts) do
    allow_missing = Keyword.get(opts, :allow_missing, false)
    allow_extra = Keyword.get(opts, :allow_extra, false)
    default_endianness = Keyword.get(opts, :default_endianness, :little)
    ir_only = Keyword.get(opts, :ir_only, false)

    with {:error, reason} <-
           _to_c_struct(
             module,
             data,
             attributes,
             allow_missing,
             allow_extra,
             default_endianness,
             true,
             Keyword.keyword?(attributes)
           ) do
      {:error, reason}
    else
      ir ->
        if ir_only do
          ir
        else
          {layout, struct_size} = CStruct.memory_layout(attributes)
          {CStruct.Nif.to_binary(ir, layout, struct_size), ir, layout, struct_size}
        end
    end
  end

  def verify_attributes(attributes) do
    with specs <- Access.get(attributes, :specs, false),
         {:spces_type, true} <- {:spces_type, Keyword.keyword?(specs) and specs != []},
         alignas <- Access.get(attributes, :alignas, false),
         {:alignas_value, true} <- {:alignas_value, is_integer(alignas) and alignas > 0},
         "1" <> alignas_binary_rep = Integer.to_string(alignas, 2),
         {:alignas_value, true} <- {:alignas_value, "" == alignas_binary_rep or 0 == String.to_integer(alignas_binary_rep)},
         pack <- Access.get(attributes, :pack, false),
         {:pack_value, true} <- {:pack_value, is_integer(pack) and pack > 0},
         "1" <> pack_binary_rep = Integer.to_string(trunc(pack), 2),
         {:pack_value, true} <- {:pack_value, "" == pack_binary_rep or 0 == String.to_integer(pack_binary_rep)}
    do
      [struct_size, error_acc] =
        for {field_name, field_specs} <- specs, reduce: [0, []] do
          [bytes_occupied, error_acc] ->
            case verify_field_specs(field_name, field_specs) do
              {:error, message} ->
                [bytes_occupied, [message | error_acc]]
              {:ok, field_size} ->
                {next_address, bytes_required, _bytes_padding} = _packing_field(bytes_occupied, field_specs, pack)
                [next_address + bytes_required, error_acc]
            end
        end
      if error_acc != [] do
        {:error, error_acc}
      else
        {:ok, trunc(Float.ceil(struct_size / alignas)) * alignas}
      end
    else
      {:spces_type, _} ->
        {:error, "specs should be a non-empty Keyword instance"}
      {:alignas_value, _} ->
        {:error, "alignas should be a positive integer and is a power of 2"}
      {:pack_value, _} ->
        {:error, "pack should be a positive integer and is a power of 2"}
    end
  end

  def verify_field_specs(field_name, field_specs) do
    with type <- Access.get(field_specs, :type, nil),
         {:field_type, _type, {:ok, field_size}} <- {:field_type, type, _field_size(type, field_specs)} do
      {:ok, field_size}
    else
      {:field_type, nil, _} ->
        {:error, "field_specs: field '#{field_name}' has no type info"}
      {:field_type, :union, {:error, message}} ->
        {:error, "field_specs: union field '#{field_name}' type error: #{message}"}
      {:field_type, _, {:error, message}} ->
        {:error, "field_specs: field '#{field_name}' type error: #{message}"}
    end
  end

  defp _packing_field(bytes_occupied, field_specs, pack) do
    field_type = field_specs[:type]
    {:ok, bytes_required} = _field_size(field_type, field_specs)
    {:ok, type_addressed_by} = _field_addressed_by(field_type, field_specs)
    field_addressed_by = min(type_addressed_by, pack)

    next_address =
      if rem(bytes_occupied, field_addressed_by) == 0 do
        bytes_occupied
      else
        div(bytes_occupied + field_addressed_by, field_addressed_by) * field_addressed_by
      end

    {next_address, bytes_required, next_address - bytes_occupied}
  end

  def memory_layout(attributes) do
    with {:ok, verified_size} <- verify_attributes(attributes) do
      pack = attributes[:pack]
      alignas = attributes[:alignas]
      struct_specs = attributes[:specs]
      {description, struct_size} =
        for {field_name, field_specs} <- struct_specs, reduce: {[], 0} do
          {description, bytes_occupied} ->
            {next_address, bytes_required, bytes_padding} = _packing_field(bytes_occupied, field_specs, pack)

            {
              [
                [
                  field: field_name, type: field_specs[:type], shape: field_specs[:shape],
                  start: next_address, size: bytes_required, padding_previous: bytes_padding
                ] | description],
              next_address + bytes_required,
            }
        end
      struct_size = trunc(Float.ceil(struct_size / alignas)) * alignas
      description = Enum.reverse(description)
      # if they don't match, then there is a bug
      ^struct_size = verified_size
      {description, struct_size}
    else
      {:error, message} ->
        {:error, message}
    end
  end

  defp _to_c_struct(
         module,
         data,
         attributes,
         allow_missing,
         allow_extra,
         default_endianness,
         true,
         true
       )
       when is_boolean(allow_missing) and is_boolean(allow_extra) do
    fields_with_data = apply(module, :keys, [data])

    with {:verified_attributes, {:ok, _struct_size}} <- {:verified_attributes, verify_attributes(attributes)},
         field_specs <- attributes[:specs],
         field_order <- Keyword.keys(field_specs),
         {:missing_fields_in_keyword, true} <-
           {:missing_fields_in_keyword,
            allow_missing or _verify_fields(fields_with_data, field_order)},
         {:extra_fields_in_keyword, true} <-
           {:extra_fields_in_keyword,
            allow_extra or _verify_fields(field_order, fields_with_data)},
         {:ok, generated_c_struct_bin} <-
           _to_memory(module, field_order, data, field_specs, default_endianness, []) do
      generated_c_struct_bin
    else
      {:error, message} ->
        {:error, message}

      {:verified_attributes, {:error, message}} ->
        {:error, message}

      {:missing_fields_in_keyword, false} ->
        {:error, "some fields in specs are not appeared in the data"}

      {:extra_fields_in_keyword, false} ->
        {:error, "some fields in the data are not declared in attributes"}
    end
    # todo: 5. call NIF
  end

  defp _to_c_struct(_module, _data, _attributes, _, _, _default_endianness, false, _),
    do: {:error, "not a valid keyword list"}

  defp _to_c_struct(_module, _data, _attributes, _, _, _default_endianness, _, false),
    do: {:error, "attributes is invalid"}

  defp _verify_fields(required_fields, fields_available) do
    # verify all fields in `fields_available` are specified in `required_fields`
    fields_available |> Enum.all?(fn field -> Enum.member?(required_fields, field) end)
  end

  defp _to_memory(
         _module,
         [],
         _keyword_list,
         _field_specs,
         _default_endianness,
         acc_memory
       ),
       do: {:ok, Enum.reverse(acc_memory)}

  defp _to_memory(
         module,
         [field | other_fields],
         data,
         field_specs,
         default_endianness,
         acc_memory
       ) do
    field_data = Access.get(data, field)
    field_spec = Access.get(field_specs, field)

    if Map.has_key?(field_spec, :type) do
      endianness = Map.get(field_spec, :endianness, default_endianness)

      {status, binary} =
        case field_spec[:type] do
          :union ->
            if Map.has_key?(field_spec, :union) do
              with {:ok, binary} <- _to_memory(field_data, :union, field_spec, endianness) do
                {:ok, binary}
              else
                {:error, reason} ->
                  {:error, reason}
              end
            else
              {:error, "field '#{field}' declared as union type, but no union specs provided"}
            end

          :struct ->
            if Map.has_key?(field_spec, :struct) do
              with {:error, reason} <-
                     to_c_struct(field_data, field_spec[:struct],
                       ir_only: true,
                       default_endianness: endianness
                     ) do
                {:error, reason}
              else
                ir ->
                  {:ir, ir}
              end
            else
              {:error, "field '#{field}' declared as union type, but no union specs provided"}
            end

          field_type ->
            {:ok, _to_memory(field_data, field_type, endianness)}
        end

      case status do
        :ok ->
          _to_memory(module, other_fields, data, field_specs, default_endianness, [
            binary | acc_memory
          ])

        :ir ->
          merged_ir =
            for struct_ir <- binary, reduce: acc_memory do
              acc ->
                [struct_ir | acc]
            end

          _to_memory(module, other_fields, data, field_specs, default_endianness, merged_ir)

        _ ->
          {status, binary}
      end
    else
      {:error, "field '#{field}' did not specify its type"}
    end
  end

  defp _to_memory(field_data, :u8, _endianness), do: <<field_data::integer()-size(8)>>

  defp _to_memory(field_data, :s8, _endianness), do: <<field_data::integer()-size(8)>>

  defp _to_memory(field_data, :u16, :little), do: <<field_data::integer()-size(16)-little>>

  defp _to_memory(field_data, :u16, :big), do: <<field_data::integer()-size(16)-big>>

  defp _to_memory(field_data, :s16, :little), do: <<field_data::integer()-size(16)-little>>

  defp _to_memory(field_data, :s16, :big), do: <<field_data::integer()-size(16)-big>>

  defp _to_memory(field_data, :u32, :little), do: <<field_data::integer()-size(32)-little>>

  defp _to_memory(field_data, :u32, :big), do: <<field_data::integer()-size(32)-big>>

  defp _to_memory(field_data, :s32, :little), do: <<field_data::integer()-size(32)-little>>

  defp _to_memory(field_data, :s32, :big), do: <<field_data::integer()-size(32)-big>>

  defp _to_memory(field_data, :u64, :little), do: <<field_data::integer()-size(64)-little>>

  defp _to_memory(field_data, :u64, :big), do: <<field_data::integer()-size(64)-big>>

  defp _to_memory(field_data, :s64, :little), do: <<field_data::integer()-size(64)-little>>

  defp _to_memory(field_data, :s64, :big), do: <<field_data::integer()-size(64)-big>>

  defp _to_memory(field_data, :f32, :little), do: <<field_data::float()-size(32)-little>>

  defp _to_memory(field_data, :f32, :big), do: <<field_data::float()-size(32)-big>>

  defp _to_memory(field_data, :f64, :little), do: <<field_data::float()-size(64)-little>>

  defp _to_memory(field_data, :f64, :big), do: <<field_data::float()-size(64)-big>>

  defp _to_memory(field_data, :c_ptr, _endianness) when is_binary(field_data) do
    # use list to note that the data should be allocated on heap
    # and in the struct this should be a pointer that points to the allocated memory
    [field_data]
  end

  defp _to_memory(field_data, :c_ptr, _endianness) when is_integer(field_data) do
    # raw pointer
    {field_data, :raw_pointer}
  end

  defp _to_memory(:nullptr, :c_ptr, _endianness) do
    :nullptr
  end

  defp _to_memory(field_data, :string, _) when is_binary(field_data) do
    [IO.iodata_to_binary([field_data, 0])]
  end

  defp _to_memory(field_data, :string, endianness) when is_list(field_data) do
    [IO.iodata_to_binary([_to_memory(field_data, [:u8], endianness), 0])]
  end

  defp _to_memory(field_data, [field_type], endianness)
       when is_list(field_data) and is_atom(field_type) do
    # this function handles all continuous nd-array
    field_data = List.flatten(field_data)

    memory =
      for elem <- field_data, reduce: <<>> do
        acc ->
          [_to_memory(elem, field_type, endianness), acc]
      end

    memory
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp _to_memory(field_data, [field_type], _endianness)
       when is_binary(field_data) and is_atom(field_type) do
    [field_data]
  end

  defp _to_memory(field_data, [field_type], endianness)
       when is_list(field_data) and is_list(field_type) do
    # recurse on list of list
    array_memory =
      for array_data <- field_data, reduce: [] do
        acc ->
          [_to_memory(array_data, field_type, endianness) | acc]
      end

    array_memory
    |> Enum.reverse()
  end

  defp _field_addressed_by(:u8, _), do: {:ok, 1}
  defp _field_addressed_by(:u16, _), do: {:ok, 2}
  defp _field_addressed_by(:u32, _), do: {:ok, 4}
  defp _field_addressed_by(:u64, _), do: {:ok, 8}
  defp _field_addressed_by(:s8, _), do: {:ok, 1}
  defp _field_addressed_by(:s16, _), do: {:ok, 2}
  defp _field_addressed_by(:s32, _), do: {:ok, 4}
  defp _field_addressed_by(:s64, _), do: {:ok, 8}
  defp _field_addressed_by(:f32, _), do: {:ok, 4}
  defp _field_addressed_by(:f64, _), do: {:ok, 8}
  defp _field_addressed_by(:c_ptr, _), do: {:ok, CStruct.Nif.ptr_size()}
  defp _field_addressed_by(:string, _), do: {:ok, CStruct.Nif.ptr_size()}

  defp _field_addressed_by([field_type], field_specs) when is_atom(field_type) do
    _field_size(field_type, field_specs)
  end

  defp _field_addressed_by([field_type], _field_specs) when is_list(field_type) do
    {:ok, CStruct.Nif.ptr_size()}
  end

  defp _field_addressed_by(:union, %{type: :union, union: union_specs}) do
    [ok_acc, error_acc] =
      union_specs
      |> Enum.reduce([[], []], fn {_field_name, field_specs}, [ok_acc, error_acc] ->
        field_type = field_specs[:type]
        case _field_addressed_by(field_type, field_specs) do
          {:ok, addressed_by} ->
            [[addressed_by | ok_acc], error_acc]
          {:error, message} ->
            [ok_acc, [message | error_acc]]
        end
    end)

    case [ok_acc, error_acc] do
      [[], []] ->
        {:error, "union field specs should be a non-empty Keyword instance"}
      [ok_acc, []] ->
        {:ok, Enum.max(ok_acc)}
      [_, errors] ->
        {:error, errors}
    end
  end

  defp _field_addressed_by(:struct, %{type: :struct, struct: struct_specs}) do
    verify_attributes(struct_specs)
  end

  defp _field_size(:u8, _), do: {:ok, 1}
  defp _field_size(:u16, _), do: {:ok, 2}
  defp _field_size(:u32, _), do: {:ok, 4}
  defp _field_size(:u64, _), do: {:ok, 8}
  defp _field_size(:s8, _), do: {:ok, 1}
  defp _field_size(:s16, _), do: {:ok, 2}
  defp _field_size(:s32, _), do: {:ok, 4}
  defp _field_size(:s64, _), do: {:ok, 8}
  defp _field_size(:f32, _), do: {:ok, 4}
  defp _field_size(:f64, _), do: {:ok, 8}
  defp _field_size(:c_ptr, _), do: {:ok, CStruct.Nif.ptr_size()}
  defp _field_size(:string, _), do: {:ok, CStruct.Nif.ptr_size()}

  defp _field_size([field_type], field_specs) when is_atom(field_type) do
    with shape <- Access.get(field_specs, :shape, nil),
         {:array_type_should_have_shape, true} <- {:array_type_should_have_shape, is_list(shape) and Enum.all?(shape, fn elem -> is_integer(elem) and elem > 0 end)},
         {:element_type, {:ok, element_size}} <- {:element_type, _field_size(field_type, field_specs)}
         do
      num_elements =
        List.to_tuple(shape)
        |> Tuple.product()

      {:ok, element_size * num_elements}
    else
      {:array_type_should_have_shape, false} ->
        {:error, "array type '#{inspect([field_type])}' should declare its shape in an integer list"}
      {:element_type, {:error, message}} ->
        {:error, "array type '#{inspect([field_type])}': element: #{message}"}
    end
  end

  defp _field_size([field_type], field_specs) when is_list(field_type) do
    with shape <- Access.get(field_specs, :shape, nil),
         {:pointer_array_type_should_have_shape, true} <- {:pointer_array_type_should_have_shape, is_list(shape) and Enum.all?(shape, fn elem -> is_integer(elem) and elem > 0 end)}
      do
      num_elements =
        List.to_tuple(shape)
        |> Tuple.product()

      {:ok, CStruct.Nif.ptr_size() * num_elements}
    else
      {:pointer_array_type_should_have_shape, false} ->
        {:error, "pointer array type '#{inspect([field_type])}' should declare its shape in an integer list"}
    end
  end

  defp _field_size(:union, %{type: :union, union: union_specs}) do
    with {:union_specs_should_be_keyword, true} <- {:union_specs_should_be_keyword, Keyword.keyword?(union_specs) and union_specs != []},
         {:all_union_fields_should_have_type, []} <- {:all_union_fields_should_have_type, Enum.reduce(union_specs, [], fn {union_field_name, union_field_specs}, acc ->
            if Access.get(union_field_specs, :type, nil) == nil do
              ["'#{union_field_name}'" | acc]
            else
              acc
            end
         end)}
    do
      [ok_union_fields, error_union_fields] =
        Enum.reduce(union_specs, [[], []], fn {field_name, field_specs}, [ok_acc, error_acc] ->
          field_type = field_specs[:type]
          case {field_type, _field_size(field_type, field_specs)} do
            {_, {:ok, size}} ->
              [[size | ok_acc], error_acc]
            {:union, {:error, message}} ->
              [ok_acc, ["union field '#{field_name}': #{message}" | error_acc]]
            {:struct, {:error, message}} ->
              [ok_acc, ["struct field '#{field_name}': #{message}" | error_acc]]
            {field_type, {:error, message}} ->
              [ok_acc, ["'#{inspect(field_type)}' field '#{field_name}': #{message}" | error_acc]]
          end
        end)

      case [ok_union_fields, error_union_fields] do
        [[], []] ->
          {:error, "union field specs should be a non-empty Keyword instance"}
        [ok_union_fields, []] ->
          {:ok, Enum.max(ok_union_fields)}
        [_, error_union_fields] ->
          error_message =
            error_union_fields
            |> Enum.reverse()
            |> Enum.join(", ")
          {:error, error_message}
      end
    else
      {:union_specs_should_be_keyword, false} ->
        {:error, "union field specs should be a non-empty Keyword instance"}
      {:all_union_fields_should_have_type, missing_types} ->
        fields_missing_type =
          missing_types
          |> Enum.reverse()
          |> Enum.join(", ")
        {:error, "#{fields_missing_type} did not specify their types"}
    end
  end

  defp _field_size(:union, %{type: :union}) do
    {:error, "declared as union type, but no union specs provided"}
  end

  defp _field_size(:struct, %{type: :struct, struct: attributes}) do
    with {:valid_struct_specs, {:ok, struct_size}} <- {:valid_struct_specs, verify_attributes(attributes)} do
      {:ok, struct_size}
    else
      {:valid_struct_specs, {:error, error_message}} ->
        {:error, error_message}
    end
  end

  defp _field_size(:struct, %{type: :struct}) do
    {:error, "declared as struct type, but no struct specs provided"}
  end

  defp _field_size(field_type, _), do: {:error, "type '#{inspect(field_type)}' is not supported"}

  defp _to_memory(field_data, :union, full_union_specs=%{type: :union, union: union_specs}, endianness) do
    with {:is_keyword_list, true} <- {:is_keyword_list, Keyword.keyword?(field_data)},
         {:is_union_specs_keyword_list, true} <-
           {:is_union_specs_keyword_list, Keyword.keyword?(union_specs)},
         keys <- Keyword.keys(field_data),
         {:num_keys, 1} <- {:num_keys, Enum.count(keys)},
         field_select <- Enum.at(keys, 0),
         {:declared_in_specs, field_select, true} <-
           {:declared_in_specs, field_select, Keyword.has_key?(union_specs, field_select)},
         field_specs <- Keyword.get(union_specs, field_select),
         {:specs_has_type, field_select, true} <-
           {:specs_has_type, field_select, Map.has_key?(field_specs, :type)} do
      real_binary_data =
        _to_memory(Keyword.get(field_data, field_select), field_specs[:type], endianness)

      real_size =
        case real_binary_data do
          real_binary_data when is_binary(real_binary_data) -> byte_size(real_binary_data)
          real_binary_data when is_list(real_binary_data) -> CStruct.Nif.ptr_size()
          {real_binary_data, [:padding, padding]} when is_binary(real_binary_data) ->
            byte_size(real_binary_data) + padding
          {real_binary_data, [:padding, padding]} when is_list(real_binary_data) ->
            CStruct.Nif.ptr_size() + padding
        end

      {:ok, max_size} = _field_size(:union, full_union_specs)

      binary =
        if real_size < max_size do
          {real_binary_data, [:padding, max_size - real_size]}
        else
          real_binary_data
        end

      {:ok, binary}
    else
      {:is_keyword_list, false} ->
        {:error,
         "the data of a union field should be provided as a keyword list that contains a single key-value pair"}

      {:is_union_specs_keyword_list, false} ->
        {:error, "the type of the union specs should be a keyword list"}

      {:num_keys, num} ->
        {:error,
         "the data of a union field should be provided as a keyword list that contains a single key-value pair, however, #{num} keys found"}

      {:declared_in_specs, field_select, false} ->
        {:error,
         "union type specified to use '#{field_select}', but '#{field_select}' not found in union specs"}

      {:specs_has_type, field_select, false} ->
        {:error, "union field '#{field_select}' did not specify its type"}
    end
  end
end
