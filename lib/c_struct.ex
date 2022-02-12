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

    IO.inspect(Keyword.keys(keyword_list))
    IO.inspect(Keyword.keys(attributes))
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
    attributes = [
      specs: %{
        re: %{:type => :f64},                           # double re;
        im: %{:type => :f32},                           # float im;
        data: %{:type => :c_ptr},                       # void * data;
        fix_size_array: %{:type => [:s32]},             # int fix_size_array[4]; // 4 <- auto inference
        fix_size_array2: %{:type => [:s64], length: 16} # int64_t fix_size_array2[16];
      },
      order: [:im, :re, :data, :fix_size_array]
    ]
    to_c_struct(keyword_list, attributes)
  end
end
