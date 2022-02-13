defmodule CStructTest do
  use ExUnit.Case

  test "to c struct with valid keyword_list and attributes" do
    keyword_list = CStruct.get_test_keyword_list()
    attributes = CStruct.get_test_attributes()
    {_binary, _ir, _layout, _struct_size} = CStruct.to_c_struct(keyword_list, attributes)
  end

  test "memory layout/alignas and pack" do
    # alignas 1, pack 1
    alignas = 1
    pack = 1
    attributes = [
      specs: %{
        c1: %{type: :u8},
        c2: %{type: :u8},
        c3: %{type: [:u8], shape: [3]},
        ptr1: %{type: :c_ptr},
      },
      order: [
        :c1,
        :c2,
        :c3,
        :ptr1
      ],
      alignas: alignas,
      pack: pack
    ]

    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 5,
        size: 8,
        padding_previous: 0
      ]
    ], 13} = CStruct.memory_layout(attributes)

    # alignas 2, pack 1
    alignas = 2
    pack = 1
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 5,
        size: 8,
        padding_previous: 0
      ]
    ], 14} = CStruct.memory_layout(attributes)

    # alignas 4, pack 1
    alignas = 4
    pack = 1
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 5,
        size: 8,
        padding_previous: 0
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 8, pack 1
    alignas = 8
    pack = 1
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 5,
        size: 8,
        padding_previous: 0
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 2, pack 2
    alignas = 2
    pack = 2
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 6,
        size: 8,
        padding_previous: 1
      ]
    ], 14} = CStruct.memory_layout(attributes)

    # alignas 4, pack 2
    alignas = 4
    pack = 2
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 6,
        size: 8,
        padding_previous: 1
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 8, pack 2
    alignas = 8
    pack = 2
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 6,
        size: 8,
        padding_previous: 1
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 4, pack 4
    alignas = 4
    pack = 4
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 8,
        size: 8,
        padding_previous: 3
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 8, pack 4
    alignas = 8
    pack = 4
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 8,
        size: 8,
        padding_previous: 3
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 8, pack 8
    alignas = 8
    pack = 8
    attributes =
      attributes
      |> Keyword.update(:alignas, alignas, fn _ -> alignas end)
      |> Keyword.update(:pack, pack, fn _ -> pack end)
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 8,
        size: 8,
        padding_previous: 3
      ]
    ], 16} = CStruct.memory_layout(attributes)

    # alignas 16, pack 16
    alignas = 16
    pack = 16
    attributes = [
      specs: %{
        c1: %{type: :u8},
        c2: %{type: :u8},
        c3: %{type: [:u8], shape: [3]},
        ptr1: %{type: :c_ptr},
        u16: %{type: :u16},
        ptr2: %{type: :c_ptr},
      },
      order: [
        :c1,
        :c2,
        :c3,
        :ptr1,
        :u16,
        :ptr2
      ],
      alignas: alignas,
      pack: pack
    ]
    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 8,
        size: 8,
        padding_previous: 3
      ],
      [field: :u16, type: :u16, shape: nil, start: 16, size: 2, padding_previous: 0],
      [
        field: :ptr2,
        type: :c_ptr,
        shape: nil,
        start: 24,
        size: 8,
        padding_previous: 6
      ],
    ], 32} = CStruct.memory_layout(attributes)
  end

  test "union field size" do
    keyword_list = [
      val: [select_u32: 1]
    ]

    attributes = [
      specs: %{
        val: %{
          type: :union,
          union: [
            other_u64: %{
              type: :u64
            },
            select_u32: %{
              type: :u32
            },
            other_s8: %{
              type: :s8
            },
            other_nd_array: %{
              type: [:u32],
              shape: [2, 2]
            },
            other_indirect_array: %{
              type: [[:u32]]
            }
          ]
        }
      },
      order: [
        :val
      ]
    ]

    # struct foo {
    #     union {
    #         uint64_t other_u64;
    #         uint32_t select_u32;
    #         int8_t other_s8;
    #         uint32_t other_nd_array[2][2];
    #         uint32_t *other_indirect_array;
    #     } val;
    # };
    # sizeof(struct foo) == 16

    [select_u32_ir] = CStruct.to_c_struct(keyword_list, attributes, ir_only: true)
    assert {<<1, 0, 0, 0>>, [:padding, 12]} = select_u32_ir
  end

  test "union in union" do
    keyword_list = [
      val: [select_u32: 1]
    ]

    attributes = [
      specs: %{
        val: %{
          type: :union,
          union: [
            other_u64: %{
              type: :u64
            },
            select_u32: %{
              type: :u32
            },
            other_s8: %{
              type: :s8
            },
            other_nd_array: %{
              type: [:u32],
              shape: [2, 2]
            },
            other_indirect_array: %{
              type: [[:u32]]
            },
            inner: %{
              type: :union,
              union: [
                inner_nd_array: %{
                  type: [:u64],
                  shape: [2, 2]
                }
              ]
            }
          ]
        }
      },
      order: [
        :val
      ]
    ]

    # struct foo {
    #     union {
    #         uint64_t other_u64;
    #         uint32_t select_u32;
    #         int8_t other_s8;
    #         uint32_t other_nd_array[2][2];
    #         uint32_t *other_indirect_array;
    #         union {
    #             uint64_t inner_nd_array[2][2];
    #         } inner;
    #     } val;
    # };
    # sizeof(struct foo) == 32

    [select_u32_ir] = CStruct.to_c_struct(keyword_list, attributes, ir_only: true)
    assert {<<1, 0, 0, 0>>, [:padding, 28]} = select_u32_ir
  end

  test "struct in struct/composite" do
    foo = [
      val: [select_u32: 1]
    ]

    bar = [
      val: [select_u64_nd_array: [[1, 2, 3], [4, 5, 6]]]
    ]

    foo_attributes = [
      specs: %{
        val: %{
          type: :union,
          union: [
            other_u64: %{
              type: :u64
            },
            select_u32: %{
              type: :u32
            },
            inner: %{
              type: :union,
              union: [
                inner_nd_array: %{
                  type: [:u64],
                  shape: [2, 2]
                }
              ]
            }
          ]
        }
      },
      order: [
        :val
      ]
    ]

    bar_attributes = [
      specs: %{
        val: %{
          type: :union,
          union: [
            select_u64_nd_array: %{
              type: [:u64],
              shape: [1, 2, 3]
            },
            inner: %{
              type: :union,
              union: [
                inner_nd_array: %{
                  type: [:u64],
                  shape: [2, 2]
                }
              ]
            }
          ]
        }
      },
      order: [
        :val
      ]
    ]

    data = [foo_part: foo, bar_part: bar]

    attributes = [
      specs: %{
        foo_part: %{
          type: :struct,
          struct: foo_attributes
        },
        bar_part: %{
          type: :struct,
          struct: bar_attributes
        }
      },
      order: [
        :foo_part,
        :bar_part
      ]
    ]

    # struct foo {
    #     union {
    #         uint64_t other_u64;
    #         uint32_t select_u32;
    #         union {
    #             uint64_t inner_nd_array[2][2];
    #         } inner;
    #     } val;
    # };
    #
    # struct bar {
    #     union {
    #         uint64_t select_u64_nd_array[1][2][3];
    #         union {
    #             uint64_t inner_nd_array[2][2];
    #         } inner;
    #     } val;
    # };
    #
    # struct composite {
    #     struct foo foo_part;
    #     struct bar bar_part;
    # };
    # sizeof(struct composite) == 80

    ir = CStruct.to_c_struct(data, attributes, ir_only: true)

    assert [
             {<<1, 0, 0, 0>>, [:padding, 28]},
             <<5, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0,
               0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0>>
           ] = ir
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

    {:error,
     "the data of a union field should be provided as a keyword list that contains a single key-value pair"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error,
     "the data of a union field should be provided as a keyword list that contains a single key-value pair"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)

    keyword_list = [a: [num1: 1, num2: 2]]
    map = %{:a => [num1: 1, num2: 2]}

    {:error,
     "the data of a union field should be provided as a keyword list that contains a single key-value pair, however, 2 keys found"} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error,
     "the data of a union field should be provided as a keyword list that contains a single key-value pair, however, 2 keys found"} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "field declared as union should provide a union specs" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: %{
        :a => %{
          :type => :union
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
