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
      iex> attributes = [specs: %{val: %{type: :u32}}, order: [:val]]
      [specs: %{val: %{type: :u32}}, order: [:val]]
      iex> CStruct.to_c_struct(data, attributes)
      <<1, 0, 0, 0>>

  ### Map
      iex> data = %{val: 1}
      %{val: 1}
      iex> attributes = [specs: %{val: %{type: :u32, endianness: :big}}, order: [:val]]
      [specs: %{val: %{type: :u32}}, order: [:val]]
      iex> CStruct.to_c_struct(data, attributes)
      <<0, 0, 0, 1>>
  """
  def to_c_struct(data, attributes, opts \\ [])
  def to_c_struct(keyword_list, attributes, opts)
      when is_list(keyword_list) and is_list(attributes) do
    allow_missing = Keyword.get(opts, :allow_missing, false)
    allow_extra = Keyword.get(opts, :allow_extra, false)
    default_endianness = Keyword.get(opts, :default_endianness, :little)

    ir = _to_c_struct(
      Keyword,
      keyword_list,
      attributes,
      allow_missing,
      allow_extra,
      default_endianness,
      Keyword.keyword?(keyword_list),
      Keyword.keyword?(attributes)
    )
    CStruct.Nif.to_binary(ir)
  end

  def to_c_struct(map_data, attributes, opts)
      when is_map(map_data) and is_list(attributes) do
    allow_missing = Keyword.get(opts, :allow_missing, false)
    allow_extra = Keyword.get(opts, :allow_extra, false)
    default_endianness = Keyword.get(opts, :default_endianness, :little)

    ir = _to_c_struct(
      Map,
      map_data,
      attributes,
      allow_missing,
      allow_extra,
      default_endianness,
      true,
      Keyword.keyword?(attributes)
    )
    CStruct.Nif.to_binary(ir)
  end

  def to_c_struct(module, data, attributes, opts) when is_list(attributes) and is_list(opts) do
    allow_missing = Keyword.get(opts, :allow_missing, false)
    allow_extra = Keyword.get(opts, :allow_extra, false)
    default_endianness = Keyword.get(opts, :default_endianness, :little)

    ir = _to_c_struct(
      module,
      data,
      attributes,
      allow_missing,
      allow_extra,
      default_endianness,
      true,
      Keyword.keyword?(attributes)
    )
    CStruct.Nif.to_binary(ir)
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

    with {:has_order, true} <- {:has_order, Keyword.has_key?(attributes, :order)},
         {:has_specs, true} <- {:has_specs, Keyword.has_key?(attributes, :specs)},
         field_order <- attributes[:order],
         field_specs <- attributes[:specs],
         {:missing_fields_in_specs, true} <-
           {:missing_fields_in_specs, _verify_fields(Map.keys(field_specs), field_order)},
         {:missing_fields_in_order, true} <-
           {:missing_fields_in_order, _verify_fields(field_order, Map.keys(field_specs))},
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
      {:error, reason} ->
        {:error, reason}

      {:has_order, false} ->
        {:error, "missing :order in attributes"}

      {:has_specs, false} ->
        {:error, "missing :specs in attributes"}

      {:missing_fields_in_specs, false} ->
        {:error, "some fields in attributes[:order] are not specified in attributes[:specs]"}

      {:missing_fields_in_order, false} ->
        {:error, "some fields in attributes[:specs] are not specified in attributes[:order]"}

      {:missing_fields_in_keyword, false} ->
        {:error, "some fields in specs are not appeared in the data"}

      {:extra_fields_in_keyword, false} ->
        {:error, "some fields in the data are not declared in attributes"}
    end

    # todo: 2. calculate the size in bytes
    # todo: 3. handle `void * data`
    # todo: 4. transform everything into binary (in C? in Elixir? seems to be easier if we do this in Elixir)
    # todo: 5. call NIF
  end

  defp _to_c_struct(_module, _keyword_list, _attributes, _, _, _default_endianness, false, _),
    do: report_error("not a valid keyword list")

  defp _to_c_struct(_module, _keyword_list, _attributes, _, _, _default_endianness, _, false),
    do: report_error("attributes is invalid")

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
    field_data = apply(module, :get, [data, field])
    field_spec = Map.get(field_specs, field)

    if Map.has_key?(field_spec, :type) do
      endianness = Map.get(field_spec, :endianness, default_endianness)

      {status, binary} =
        case field_spec[:type] do
          :union ->
            if Map.has_key?(field_spec, :union) do
              with {:ok, binary} <- _to_memory(field_data, :union, field_spec[:union], endianness) do
                {:ok, binary}
              else
                {:error, reason} ->
                  {:error, reason}
              end
            else
              {:error, "field '#{field}' declared as union type, but no union specs provided"}
            end

          field_type ->
            {:ok, _to_memory(field_data, field_type, endianness)}
        end

      if status == :ok do
        _to_memory(module, other_fields, data, field_specs, default_endianness, [
          binary | acc_memory
        ])
      else
        {status, binary}
      end
    else
      {:error, "field '#{field}' did not specify its type"}
    end
  end

  defp _to_memory(field_data, :u8, _), do: <<field_data::integer()-size(8)>>

  defp _to_memory(field_data, :s8, _), do: <<field_data::integer()-size(8)>>

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

  defp _to_memory(field_data, :union, union_specs, endianness) do
    with {:is_keyword_list, true} <- {:is_keyword_list, Keyword.keyword?(field_data)},
         {:is_union_specs_keyword_list, true} <- {:is_union_specs_keyword_list, Keyword.keyword?(union_specs)},
         keys <- Keyword.keys(field_data),
         {:num_keys, 1} <- {:num_keys, Enum.count(keys)},
         field_select <- Enum.at(keys, 0),
         {:declared_in_specs, field_select, true} <-
           {:declared_in_specs, field_select, Keyword.has_key?(union_specs, field_select)},
         field_specs <- Keyword.get(union_specs, field_select),
         {:specs_has_type, field_select, true} <-
           {:specs_has_type, field_select, Map.has_key?(field_specs, :type)} do
      {:ok, _to_memory(Keyword.get(field_data, field_select), field_specs[:type], endianness)}
    else
      {:is_keyword_list, false} ->
        {:error,
         "the data of a union field should be provided as a keyword list that contains a single key-value pair"}

      {:is_union_specs_keyword_list, false} ->
        {:error,
          "the type of the union specs should be a keyword list"}

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

  defp report_error(reason) do
    {:error, reason}
  end

  def get_test_keyword_list() do
    [
      im: 1,
      re: 1,
      data: <<1, 2, 3, 4>>,
      data_size: 4,
      fix_size_array: [5, 6, 7, 8],
      fix_size_array2: [9, 10, 11, 12],
      array_of_array: [[13, 14, 15, 16], [17, 18, 19, 20]],
      array_of_array_size: [4, 4],
      array_of_array_of_array: [
        [[21, 22, 23, 24]],
        [[25, 26, 27, 28, 29]],
        [[30, 31, 32, 34, 35, 36]]
      ],
      array_of_array_of_array_size: [[4], [5], [6]],
      matrix_2d: [
        [37, 38, 39],
        [40, 41, 42]
      ],
      matrix_3d: [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ],
      message: "hello world",
      message2: "hello world!",
      message3: "null-terminated",
      ptr_but_null: :nullptr,
      union_data1: [num: 123],
      union_data2: [str: "456"],
      s8: 127,
      le_s16: 12345,
      be_u16: 12345,
      be_u32: 12345,
      be_u64: 12345,
      be_s16: -12345,
      be_s32: -12345,
      be_s64: -12345,
      be_f32: 123.456,
      be_f64: -123.456,
      null_terminated_string: "hello",
      null_terminated_iodata: [1, 2, 4, 8],
    ]
  end

  def get_test_attributes() do
    # todo: support align?
    # todo: support bitfield?
    [
      specs: %{
        # double re;
        re: %{:type => :f64},
        # float im;
        im: %{:type => :f32},
        # void * data;
        data: %{:type => :c_ptr},
        # uint64_t data_size; // uint64_t is basically size_t, but might not be true for 32bit OS?
        data_size: %{:type => :u64},
        # int fix_size_array[4]; // 4 <- auto inference
        fix_size_array: %{:type => [:s32]},
        # int64_t fix_size_array2[16];
        fix_size_array2: %{:type => [:s64], length: 16},
        # uint32_t * array_of_array[2];
        array_of_array: %{:type => [[:u32]], length: 2},
        # uint64_t array_of_array_size[2]; // array_of_array_size[i]: #elements in in array_of_array[i]
        array_of_array_size: %{:type => [:u64]},
        # uint8_t ** array_of_array_of_array[3];
        array_of_array_of_array: %{
          :type => [[[:u8]]],
          length: 3
        },
        # uint64_t array_of_array_of_array_size[3][1];
        array_of_array_of_array_size: %{
          :type => [:u64]
        },
        # uint32_t matrix_2d[2][3];
        matrix_2d: %{
          :type => [:u32]
        },
        # uint16_t matrix_3d[1][2][3];
        matrix_3d: %{
          :type => [:u16]
        },
        # void * message;       // not necessarily null-terminated, depends on the data passed
        message: %{:type => :c_ptr},
        # uint8_t message2[12]; // not necessarily null-terminated, depends on the data passed
        message2: %{:type => [:u8]},
        # const char * message3; // guaranteed to be null-terminated for :string
        message3: %{:type => :string},
        ptr_but_null: %{:type => :c_ptr},
        # union {
        #   uint32_t num;
        #   void * str;
        # } union_data1;
        union_data1: %{
          :type => :union,
          :union => [
            num: %{
              :type => :u32
            },
            str: %{
              :type => :c_ptr
            }
          ]
        },
        # union {
        #   uint32_t num;
        #   void * str;
        # } union_data2;
        union_data2: %{
          :type => :union,
          :union => [
            num: %{
              :type => :u32
            },
            str: %{
              :type => :c_ptr
            }
          ]
        },
        s8: %{
          :type => :s8,
        },
        le_s16: %{
          :type => :s16,
        },
        be_u16: %{
          :type => :u16,
          :endianness => :big
        },
        be_u32: %{
          :type => :u32,
          :endianness => :big
        },
        be_u64: %{
          :type => :u64,
          :endianness => :big
        },
        be_s16: %{
          :type => :s16,
          :endianness => :big
        },
        be_s32: %{
          :type => :s32,
          :endianness => :big
        },
        be_s64: %{
          :type => :s64,
          :endianness => :big
        },
        be_f32: %{
          :type => :f32,
          :endianness => :big
        },
        be_f64: %{
          :type => :f64,
          :endianness => :big
        },
        null_terminated_string: %{
          :type => :string
        },
        null_terminated_iodata: %{
          :type => :string
        }
      },
      # this specifies the order of these fields, i.e., memory layout
      order: [
        :im,
        :re,
        :data,
        :data_size,
        :fix_size_array,
        :fix_size_array2,
        :array_of_array,
        :array_of_array_size,
        :array_of_array_of_array,
        :array_of_array_of_array_size,
        :matrix_2d,
        :matrix_3d,
        :message,
        :message2,
        :message3,
        :ptr_but_null,
        :union_data1,
        :union_data2,
        :s8,
        :le_s16,
        :be_u16,
        :be_u32,
        :be_u64,
        :be_s16,
        :be_s32,
        :be_s64,
        :be_f32,
        :be_f64,
        :null_terminated_string,
        :null_terminated_iodata
      ]
    ]
  end
end
