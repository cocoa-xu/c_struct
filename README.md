# CStruct

Interacts with C structs.

## Examples
### `CStruct.verify_attributes/1`
Suppose we have the following C struct
```c
#pragma pack(push, 1)
struct alignas(1) example {
    union {
        union {
            uint8_t u8;
            uint16_t u16;
        } foo;
        union {
            uint16_t u16;
            void * ptr;
        } bar;
    } val;
};
#pragma pack(pop)
```

then we can write its attributes as follows,

```elixir
attributes = [
  pack: 1,
  alignas: 1,
  specs: [
    val: %{
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
    }
  ]
]

# using CStruct.verify_attributes/1 to verify the specs and get struct size
{:ok, struct_size} = CStruct.verify_attributes(attributes)
^struct_size = 8
```

### `CStruct.memory_layout/1`
A more complex example, using a struct in another struct.
```c
#pragma pack(push, 4)
struct alignas(4) bar {
    uint8_t u8;
    uint16_t u16;
};
#pragma pack(pop)

#pragma pack(push, 1)
struct alignas(1) example {
    uint8_t c1;
    uint8_t c2;
    uint8_t c3[3];
    union {
        uint8_t u8;
        uint16_t u16;
    } foo;
    struct bar bar;
    void * ptr1;
};
#pragma pack(pop)
```

```elixir
# alignas 1, pack 1
bar_attributes = [
  alignas: 4,
  pack: 4,
  specs: [
    u8: %{type: :u8},
    u16: %{type: :u16},
  ]
]
example_attributes = [
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
      struct: bar_attributes
    },
    ptr1: %{type: :c_ptr},
  ],
  alignas: 1,
  pack: 1
]
ptr_size = CStruct.Nif.ptr_size()

# using CStruct.memory_layout/1 to get the memory layout plan based on attributes
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
```

### `CStruct.to_c_struct/2` (WIP)
```c
#pragma pack(push, 2)
struct alignas(8) example {
    uint32_t val[2];
};
#pragma pack(pop)
```

```elixir
# using CStruct.to_c_struct/2 to get 
#  - binary: the memory chunk for this struct
#  - allocated_raw_resource: allocated memory pointers
#  - ir: intermediate representation using by CStruct
#  - layout: memory layout plan
#  - struct_size
data = [val: [42, 43]]
attributes = [specs: [val: %{type: [:u32], shape: [2]}], alignas: 8, pack: 2]
{binary, allocated_raw_resource=[], _ir, _layout, ^struct_size} = CStruct.to_c_struct(data, attributes)
<<42, 0, 0, 0, 43, 0, 0, 0>> = binary
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `c_struct` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:c_struct, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/c_struct>.

