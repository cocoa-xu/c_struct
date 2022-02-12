defmodule CStruct do
  @moduledoc """
  Convert elixir Maps/Keyword List to C structs
  """

  @doc """
  Hello world.

  ## Examples

      iex> CStruct.hello()
      :world

  """
  def to_c_struct(keyword_list) when is_list(keyword_list) do
    _to_c_struct(keyword_list, [], Keyword.keyword?(keyword_list), true)
  end

  def to_c_struct(keyword_list, nil) when is_list(keyword_list) do
    _to_c_struct(keyword_list, [], Keyword.keyword?(keyword_list), true)
  end

  def to_c_struct(keyword_list, attributes) when is_list(keyword_list) and is_list(attributes) do
    _to_c_struct(keyword_list, attributes, Keyword.keyword?(keyword_list), Keyword.keyword?(attributes))
  end

  defp _to_c_struct(keyword_list, attributes, true, true) do
    fields_with_data = Keyword.keys(keyword_list)
    fields_with_explict_attr = Keyword.validate(attributes, [order: fields_with_data])

    # todo: 1. verify all fields in `fields_with_data` are specified in `order`
    # todo: 2. calculate the size in bytes
    # todo: 3. handle `void * data`
    # todo: 4. transform everything into binary (in C? in Elixir? seems to be easier if we do this in Elixir)
    # todo: 5. call NIF
  end

  defp _to_c_struct(_keyword_list, _attributes, _, _), do: report_error("Not a valid Keyword List")

  defp report_error(reason) do
    {:error, reason}
  end

  def test do
    keyword_list = [
      im: 1,
      re: 1,
      data: <<1, 2, 3, 4>>,
      fix_size_array:  [1, 2, 3, 4],
      fix_size_array2: [1, 2, 3, 4]
    ]

    # todo: support align?
    # todo: support bitfield?
    attributes = [
      specs: %{
        re: %{:type => :f64},                           # double re;
        im: %{:type => :f32},                           # float im;
        data: %{:type => :c_ptr},                       # void * data;
        data_size: %{:type => :u64},                    # uint64_t data_size; // uint64_t is basically size_t, but might not be true for 32bit OS?
        fix_size_array: %{:type => [:s32]},             # int fix_size_array[4]; // 4 <- auto inference
        fix_size_array2: %{:type => [:s64], length: 16} # int64_t fix_size_array2[16];
      },
      order: [                                          # this specifies the order of these fields, i.e., memory layout
        :im, :re,
        :data, :data_size,
        :fix_size_array, :fix_size_array2
      ]
    ]
    to_c_struct(keyword_list, attributes)
  end
end
