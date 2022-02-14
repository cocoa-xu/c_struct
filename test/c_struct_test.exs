defmodule CStructTest do
  use ExUnit.Case

  test "test with valid inputs/basic types" do
    # #pragma pack(push, 1)
    # struct alignas(1) test {
    #   uint8_t val;
    # };
    # #pragma pack(pop)
    data = [val: 42]
    attributes = [specs: [val: %{type: :u8}], alignas: 1, pack: 1]
    {:ok, struct_size} = CStruct.verify_attributes(attributes)
    {binary, allocated_raw_resource=[], _ir, _layout, ^struct_size} = CStruct.to_c_struct(data, attributes)
    << 42::integer-size(8) >> = binary

    # #pragma pack(push, 2)
    # struct alignas(8) test {
    #   uint32_t val[2];
    # };
    # #pragma pack(pop)
    data = [val: [42, 43]]
    attributes = [specs: [val: %{type: [:u32], shape: [2]}], alignas: 8, pack: 2]
    {:ok, struct_size} = CStruct.verify_attributes(attributes)
    {binary, allocated_raw_resource=[], _ir, _layout, ^struct_size} = CStruct.to_c_struct(data, attributes)
    <<42, 0, 0, 0, 43, 0, 0, 0>> = binary

    # #pragma pack(push, 2)
    # struct alignas(8) test {
    #   uint16_t *val[1];
    # };
    # #pragma pack(pop)
    # uint16_t values[3] = {42, 43, 44};
    # struct test t = {.val = values};
    data = [val: [42, 43, 44]]
    attributes = [specs: [val: %{type: [[:u16]], shape: [1]}], alignas: 8, pack: 2]
    {:ok, struct_size} = CStruct.verify_attributes(attributes)
    {binary, allocated_raw_resource, ir, layout, ^struct_size} = CStruct.to_c_struct(data, attributes)
    IO.inspect(layout)
    IO.inspect(ir)
    IO.inspect(allocated_raw_resource)
    IO.inspect(binary)
  end

  test "test with valid inputs" do
    data = get_test_data()
    attributes = get_test_attributes()
    {:ok, struct_size} = CStruct.verify_attributes(attributes)
    {binary, allocated_raw_resource, ir, _layout, ^struct_size} = CStruct.to_c_struct(data, attributes)
    IO.inspect({binary, ir})
  end

  test "verify attributes" do
    attributes = [specs: nil]
    {:error, "specs should be a non-empty Keyword instance"} = CStruct.verify_attributes(attributes)

    attributes = [specs: []]
    {:error, "specs should be a non-empty Keyword instance"} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{}]]
    {:error, "alignas should be a positive integer and is a power of 2"} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{}], alignas: 1]
    {:error, "pack should be a positive integer and is a power of 2"} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{}], alignas: 1, pack: 1]
    {:error, ["field_specs: field 'val' has no type info"]} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{type: :non_exist_type}], alignas: 1, pack: 1]
    {:error, ["field_specs: field 'val' type error: type ':non_exist_type' is not supported"]} = CStruct.verify_attributes(attributes)

    # uint8_t val;
    attributes = [specs: [val: %{type: :u8}], alignas: 1, pack: 1]
    {:ok, 1} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{type: [:non_exist_type]}], alignas: 1, pack: 1]
    {:error, ["field_specs: field 'val' type error: array type '[:non_exist_type]' should declare its shape in an integer list"]} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{type: [:non_exist_type], shape: [8]}], alignas: 1, pack: 1]
    {:error, ["field_specs: field 'val' type error: array type '[:non_exist_type]': element: type ':non_exist_type' is not supported"]} = CStruct.verify_attributes(attributes)

    # uint16_t val[8];
    attributes = [specs: [val: %{type: [:u16], shape: [8]}], alignas: 1, pack: 1]
    {:ok, 16} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{type: [[:u32]]}], alignas: 1, pack: 1]
    {:error, ["field_specs: field 'val' type error: pointer array type '[[:u32]]' should declare its shape in an integer list"]} = CStruct.verify_attributes(attributes)

    # uint64_t * val[16];
    attributes = [specs: [val: %{type: [[:u64]], shape: [16]}], alignas: 1, pack: 1]
    {:ok, 128} = CStruct.verify_attributes(attributes)

    # int8_t ** val[32];
    attributes = [specs: [val: %{type: [[[:s8]]], shape: [32]}], alignas: 1, pack: 1]
    {:ok, 256} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{type: [[[:s16]], :invalid], shape: [32]}], alignas: 1, pack: 1]
    {:error, ["field_specs: field 'val' type error: type '[[[:s16]], :invalid]' is not supported"]} = CStruct.verify_attributes(attributes)

    # int32_t *** val[1];
    # int32_t *** val;
    attributes = [specs: [val: %{type: [[[[:s32]]]], shape: [1]}], alignas: 1, pack: 1]
    {:ok, 8} = CStruct.verify_attributes(attributes)

    # int64_t *** val[2][3][4];
    attributes = [specs: [val: %{type: [[[[:s64]]]], shape: [2, 3, 4]}], alignas: 1, pack: 1]
    {:ok, 192} = CStruct.verify_attributes(attributes)

    # float val[100][200];
    attributes = [specs: [val: %{type: [:f32], shape: [100, 200]}], alignas: 1, pack: 1]
    {:ok, 80000} = CStruct.verify_attributes(attributes)

    # double val[200][400];
    attributes = [specs: [val: %{type: [:f64], shape: [200, 400]}], alignas: 1, pack: 1]
    {:ok, 640000} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{
      type: :union,
      union: []
    }], alignas: 1, pack: 1]
    {:error, ["field_specs: union field 'val' type error: union field specs should be a non-empty Keyword instance"]} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{
      type: :union,
      union: [
        u8: %{},
      ]
    }], alignas: 1, pack: 1]
    {:error, ["field_specs: union field 'val' type error: 'u8' did not specify their types"]} = CStruct.verify_attributes(attributes)

    # union {
    #   uint8_t u8;
    #   uint16_t u16;
    #   void * ptr;
    # } val;
    attributes = [specs: [val: %{
      type: :union,
      union: [
        u8: %{type: :u8},
        u16: %{type: :u16},
        ptr: %{type: :c_ptr},
      ]
    }], alignas: 1, pack: 1]
    {:ok, 8} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{
      type: :union,
      union: [
        foo: %{
          type: :union,
          union: [
            u8: %{type: :u8},
            u16: %{},
          ]
        },
        bar: %{
          type: :union,
          union: [
            u16: %{type: :u16},
            ptr: %{},
          ]
        },
      ]
    }], alignas: 1, pack: 1]
    {:error, ["field_specs: union field 'val' type error: union field 'foo': 'u16' did not specify their types, union field 'bar': 'ptr' did not specify their types"]} = CStruct.verify_attributes(attributes)

#     struct {
#       union {
#         uint8_t u8;
#         uint16_t u16;
#       } foo;
#       union {
#         uint16_t u16;
#         void * ptr;
#       } bar;
#     };
    attributes = [specs: [val: %{
      type: :union,
      union: [
        foo: %{
          type: :union,
          union: [
            u8: %{type: :u8},
            u16: %{type: :u16},
          ]
        },
        bar: %{
          type: :union,
          union: [
            u16: %{type: :u16},
            ptr: %{type: :c_ptr},
          ]
        },
      ]
    }], alignas: 1, pack: 1]
    {:ok, 8} = CStruct.verify_attributes(attributes)

    attributes = [specs: [val: %{
      type: :union,
      union: [
        foo: %{
          type: :union,
          union: [
            u8: %{type: :u8},
            u16: %{},
          ]
        },
        bar: %{
          type: :struct,
          struct: [
            specs: [
              u64: %{type: :u64},
              u32: %{type: [:u32]}
            ],
            alignas: 1,
            pack: 1
          ]
        },
      ]
    }], alignas: 1, pack: 1]
    {:error, ["field_specs: union field 'val' type error: union field 'foo': 'u16' did not specify their types, struct field 'bar': field_specs: field 'u32' type error: array type '[:u32]' should declare its shape in an integer list"]} = CStruct.verify_attributes(attributes)

    # struct {
    #   union {
    #     uint8_t u8;
    #     uint16_t u16;
    #   } foo;
    #   struct {
    #     uint64_t u64;
    #     uint32_t u32[4];
    #   } bar;
    # };
    attributes = [specs: [val: %{
      type: :union,
      union: [
        foo: %{
          type: :union,
          union: [
            u8: %{type: :u8},
            u16: %{type: :u16},
          ]
        },
        bar: %{
          type: :struct,
          struct: [
            specs: [
              u64: %{type: :u64},
              u32: %{type: [:u32], shape: [4]}
            ],
            alignas: 1,
            pack: 1
          ]
        },
      ]
    }], alignas: 1, pack: 1]
    {:ok, 24} = CStruct.verify_attributes(attributes)
  end

  test "memory layout/alignas and pack" do
    # alignas 1, pack 1
    alignas = 1
    pack = 1
    attributes = [
      specs: [
        c1: %{type: :u8},
        c2: %{type: :u8},
        c3: %{type: [:u8], shape: [3]},
        foo: %{
          type: :union,
          union: [
            u8: %{type: :u8},
            u16: %{type: :u16},
          ],
        },
        bar: %{
          type: :struct,
          struct: [
            specs: [
              u8: %{type: :u8},
              u16: %{type: :u16},
            ],
            alignas: 4,
            pack: 4
          ]
        },
        ptr1: %{type: :c_ptr},
      ],
      alignas: alignas,
      pack: pack
    ]
    ptr_size = CStruct.Nif.ptr_size()

    {[
      [field: :c1, type: :u8, shape: nil, start: 0, size: 1, padding_previous: 0],
      [field: :c2, type: :u8, shape: nil, start: 1, size: 1, padding_previous: 0],
      [field: :c3, type: [:u8], shape: [3], start: 2, size: 3, padding_previous: 0],
      [field: :foo, type: :union, shape: nil, start: 5, size: 2, padding_previous: 0],
      [field: :bar, type: :struct, shape: nil, start: bar_start=7, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 11,
        size: ^ptr_size,
        padding_previous: 0
      ],
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = bar_start + bar_size + ptr_size

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
      [field: :foo, type: :union, shape: nil, start: 5, size: 2, padding_previous: 0],
      [field: :bar, type: :struct, shape: nil, start: bar_start=7, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 11,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 5, size: 2, padding_previous: 0],
      [field: :bar, type: :struct, shape: nil, start: bar_start=7, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 11,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 5, size: 2, padding_previous: 0],
      [field: :bar, type: :struct, shape: nil, start: bar_start=7, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 11,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 6, size: 2, padding_previous: 1],
      [field: :bar, type: :struct, shape: nil, start: bar_start=8, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 12,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 6, size: 2, padding_previous: 1],
      [field: :bar, type: :struct, shape: nil, start: bar_start=8, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 12,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 6, size: 2, padding_previous: 1],
      [field: :bar, type: :struct, shape: nil, start: bar_start=8, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 12,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 6, size: 2, padding_previous: 1],
      [field: :bar, type: :struct, shape: nil, start: bar_start=8, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 12,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 6, size: 2, padding_previous: 1],
      [field: :bar, type: :struct, shape: nil, start: bar_start=8, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 12,
        size: ^ptr_size,
        padding_previous: 0
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

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
      [field: :foo, type: :union, shape: nil, start: 6, size: 2, padding_previous: 1],
      [field: :bar, type: :struct, shape: nil, start: bar_start=8, size: bar_size=4, padding_previous: 0],
      [
        field: :ptr1,
        type: :c_ptr,
        shape: nil,
        start: 16,
        size: ^ptr_size,
        padding_previous: 4
      ]
    ], struct_size} = CStruct.memory_layout(attributes)
    ^struct_size = trunc(Float.ceil((bar_start + bar_size + ptr_size) / alignas) * alignas)

    # alignas 16, pack 16
    alignas = 16
    pack = 16
    attributes = [
      specs: [
        c1: %{type: :u8},
        c2: %{type: :u8},
        c3: %{type: [:u8], shape: [3]},
        ptr1: %{type: :c_ptr},
        u16: %{type: :u16},
        ptr2: %{type: :c_ptr},
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
        size: ^ptr_size,
        padding_previous: 3
      ],
      [field: :u16, type: :u16, shape: nil, start: u16_start, size: 2, padding_previous: 0],
      [
        field: :ptr2,
        type: :c_ptr,
        shape: nil,
        start: ptr2_start,
        size: ^ptr_size,
        padding_previous: 6
      ],
    ], struct_size} = CStruct.memory_layout(attributes)
    ^u16_start = 8 + ptr_size
    ^struct_size = trunc(Float.ceil((ptr2_start + ptr_size) / alignas) * alignas)
  end

  test "union field size" do
    keyword_list = [
      val: [select_u32: 1]
    ]

    attributes = [
      specs: [
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
              type: [[:u32]],
              shape: [1]
            }
          ]
        }
      ],
      alignas: 8,
      pack: 2,
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
      specs: [
        val: %{
          type: :union,
          union: [
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
      ],
      alignas: 2,
      pack: 2
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
      specs: [
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
      ],
      alignas: 8,
      pack: 8
    ]

    bar_attributes = [
      specs: [
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
      ],
      alignas: 8,
      pack: 8
    ]

    data = [foo_part: foo, bar_part: bar]

    attributes = [
      specs: [
        foo_part: %{
          type: :struct,
          struct: foo_attributes
        },
        bar_part: %{
          type: :struct,
          struct: bar_attributes
        }
      ],
      alignas: 8,
      pack: 8
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

  test "not allow fields missing in the data" do
    keyword_list = [a: 1]
    map = %{:a => 1}

    attributes = [
      specs: [
        a: %{:type => :u32},
        b: %{:type => :u32}
      ],
      alignas: 8,
      pack: 8,
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
      specs: [
        a: %{:type => :u32}
      ],
      alignas: 8,
      pack: 1
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
      specs: [
        a: %{}
      ],
      alignas: 8,
      pack: 8
    ]

    {:error, ["field_specs: field 'a' has no type info"]} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error, ["field_specs: field 'a' has no type info"]} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "data of a union field should be a keyword list that contains a single key-value pair" do
    keyword_list = [a: 1]
    map = %{:a => 1}

    attributes = [
      specs: [
        a: %{
          type: :union,
          union: [
            num: %{:type => :u32}
          ]
        }
      ],
      alignas: 4,
      pack: 4
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
      specs: [
        a: %{
          type: :union
        }
      ],
      alignas: 1,
      pack: 1,
    ]

    {:error, ["field_specs: union field 'a' type error: declared as union type, but no union specs provided"]} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error, ["field_specs: union field 'a' type error: declared as union type, but no union specs provided"]} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "union specs should be a keyword list" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      order: [:a],
      specs: [
        a: %{
          :type => :union,
          :union => %{}
        }
      ],
      alignas: 8,
      pack: 8
    ]

    {:error, ["field_specs: union field 'a' type error: union field specs should be a non-empty Keyword instance"]} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error, ["field_specs: union field 'a' type error: union field specs should be a non-empty Keyword instance"]} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "selected union field should have key :type" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      specs: [
        a: %{
          :type => :union,
          :union => [
            num: %{}
          ]
        }
      ],
      alignas: 4,
      pack: 4
    ]

    {:error, ["field_specs: union field 'a' type error: 'num' did not specify their types"]} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error, ["field_specs: union field 'a' type error: 'num' did not specify their types"]} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  test "selected union field should appear in the union specs" do
    keyword_list = [a: [num: 1]]
    map = %{:a => [num: 1]}

    attributes = [
      specs: [
        a: %{
          type: :union,
          union: [
            other: %{:type => :c_ptr}
          ]
        }
      ],
      alignas: 8,
      pack: 4,
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
      specs: [
        a: %{
          :type => :union,
          :union => [
            num: %{}
          ]
        }
      ],
      alignas: 4,
      pack: 1
    ]

    {:error, ["field_specs: union field 'a' type error: 'num' did not specify their types"]} =
      CStruct.to_c_struct(keyword_list, attributes, allow_missing: true, allow_extra: false)

    {:error, ["field_specs: union field 'a' type error: 'num' did not specify their types"]} =
      CStruct.to_c_struct(map, attributes, allow_missing: true, allow_extra: false)
  end

  def get_test_data() do
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
      null_terminated_iodata: [1, 2, 4, 8]
    ]
  end

  def get_test_attributes() do
    # todo: support bitfield?
    [
      alignas: 8,
      pack: 8,
      specs: [
        # double re;
        re: %{:type => :f64},
        # float im;
        im: %{:type => :f32},
        # void * data;
        data: %{:type => :c_ptr},
        # uint64_t data_size; // uint64_t is basically size_t, but might not be true for 32bit OS?
        data_size: %{:type => :u64},
        # int32_t fix_size_array[4];
        fix_size_array: %{:type => [:s32], :shape => [4]},
        # int64_t fix_size_array2[16];
        fix_size_array2: %{:type => [:s64], :shape => [16]},
        # uint32_t * array_of_array[2];
        array_of_array: %{:type => [[:u32]], :shape => [2]},
        # uint64_t array_of_array_size[2];
        array_of_array_size: %{:type => [:u64], :shape => [2]},
        # uint8_t ** array_of_array_of_array[3];
        array_of_array_of_array: %{
          :type => [[[:u8]]],
          :shape => [3]
        },
        # uint64_t array_of_array_of_array_size[3][1];
        array_of_array_of_array_size: %{
          :type => [:u64],
          :shape => [3, 1]
        },
        # uint32_t matrix_2d[2][3];
        matrix_2d: %{
          :type => [:u32],
          :shape => [2, 3]
        },
        # uint16_t matrix_3d[1][2][3];
        matrix_3d: %{
          :type => [:u16],
          :shape => [1, 2, 3]
        },
        # void * message;       // not necessarily null-terminated, depends on the data passed
        message: %{:type => :c_ptr},
        # uint8_t message2[16]; // not necessarily null-terminated, depends on the data passed
        message2: %{:type => [:u8], :shape => [16]},
        # const char * message3; // guaranteed to be null-terminated for :string
        message3: %{:type => :string},
        ptr_but_null: %{:type => :c_ptr},
        # union {
        #   uint32_t num;
        #   void * str;
        # } union_data1;
        union_data1: %{
          type: :union,
          union: [
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
          type: :union,
          union: [
            num: %{
              :type => :u32
            },
            str: %{
              :type => :c_ptr
            }
          ]
        },
        s8: %{
          :type => :s8
        },
        le_s16: %{
          :type => :s16
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
      ],
    ]
  end
end
