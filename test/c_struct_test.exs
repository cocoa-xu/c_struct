defmodule CStructTest do
  use ExUnit.Case

  test "to c struct with valid keyword_list and attributes" do
    keyword_list = CStruct.get_test_keyword_list()
    attributes = CStruct.get_test_attributes()
    generated_c_struct_bin = CStruct.to_c_struct(keyword_list, attributes)
    assert is_list(generated_c_struct_bin)
  end

  test "to c struct with invalid keyword_list and/or attributes" do
    valid_keyword_list = []
    valid_attributes = []
    invalid_keyword_list = [1]
    invalid_attributes = [1]

    {:error, "not a valid keyword list"} =
      CStruct.to_c_struct(invalid_keyword_list, valid_attributes)

    {:error, "not a valid keyword list"} =
      CStruct.to_c_struct(invalid_keyword_list, invalid_attributes)

    {:error, "attributes is invalid"} =
      CStruct.to_c_struct(valid_keyword_list, invalid_attributes)
  end

  test "fields declared in attributes[:order] should all appear in attributes[:specs]" do
    keyword_list = [a: 1]
    map = %{:a => 1}
    attributes = [order: [:a], specs: %{}]

    {:error, "some fields in attributes[:order] are not specified in attributes[:specs]"} =
      CStruct.to_c_struct(keyword_list, attributes)
    {:error, "some fields in attributes[:order] are not specified in attributes[:specs]"} =
      CStruct.to_c_struct(map, attributes)
  end

  test "fields declared in attributes[:specs] should all appear in attributes[:order]" do
    keyword_list = [a: 1]
    map = %{:a => 1}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{:type => :u32},
        :b => %{:type => :u32}
      }
    ]

    {:error, "some fields in attributes[:specs] are not specified in attributes[:order]"} =
      CStruct.to_c_struct(keyword_list, attributes)
    {:error, "some fields in attributes[:specs] are not specified in attributes[:order]"} =
      CStruct.to_c_struct(map, attributes)
  end

  test "not allow fields missing in the data" do
    keyword_list = [a: 1]
    map = %{:a => 1}

    attributes = [
      order: [:a, :b],
      specs: %{
        :a => %{:type => :u32},
        :b => %{:type => :u32}
      }
    ]

    {:error, "some fields in specs are not appeared in the data"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: false)
    {:error, "some fields in specs are not appeared in the data"} =
      CStruct.to_c_struct(map, attributes, allow_missing: false)
  end

  test "not allow extra fields in keyword list" do
    keyword_list = [a: 1, extra: 2]
    map = %{:a => 1, :extra => 2}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{:type => :u32}
      }
    ]

    {:error, "some fields in the data are not declared in attributes"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "some fields in the data are not declared in attributes"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "specs should have key :type" do
    keyword_list = [a: 1]
    map = %{:a => 1}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{}
      }
    ]

    {:error, "field 'a' did not specify its type"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "field 'a' did not specify its type"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "data of a union field should be a keyword list that contains a single key-value pair" do
    keyword_list = [a: 1]
    map = %{:a => 1}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union,
          :union => [
            num: %{
              :type => :u32
            }
          ]
        }
      }
    ]

    {:error, "the data of a union field should be provided as a keyword list that contains a single key-value pair"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "the data of a union field should be provided as a keyword list that contains a single key-value pair"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)

    keyword_list = [a: [num1: 1, num2: 2]]
    map = %{:a => [num1: 1, num2: 2]}
    {:error, "the data of a union field should be provided as a keyword list that contains a single key-value pair, however, 2 keys found"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "the data of a union field should be provided as a keyword list that contains a single key-value pair, however, 2 keys found"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "field declared as union should provide a union specs" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union,
        }
      }
    ]

    {:error, "field 'a' declared as union type, but no union specs provided"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "field 'a' declared as union type, but no union specs provided"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "union specs should be a keyword list" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union,
          :union => %{}
        }
      }
    ]

    {:error, "the type of the union specs should be a keyword list"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "the type of the union specs should be a keyword list"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "selected union field should have key :type" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union,
          :union => [
            num: %{}
          ]
        }
      }
    ]

    {:error, "union field 'num' did not specify its type"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "union field 'num' did not specify its type"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "selected union field should appear in the union specs" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union,
          :union => [
            other: %{}
          ]
        }
      }
    ]

    {:error, "union type specified to use 'num', but 'num' not found in union specs"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "union type specified to use 'num', but 'num' not found in union specs"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "union field should have key :type" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union,
          :union => [
            num: %{}
          ]
        }
      }
    ]

    {:error, "union field 'num' did not specify its type"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)
    {:error, "union field 'num' did not specify its type"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end
end
