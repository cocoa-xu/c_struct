#include <erl_nif.h>
#include "nif_utils.hpp"

#ifdef __GNUC__
#  pragma GCC diagnostic ignored "-Wunused-parameter"
#  pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#  pragma GCC diagnostic ignored "-Wunused-variable"
#  pragma GCC diagnostic ignored "-Wunused-function"
#endif

struct c_struct_layout {
    std::vector<uint64_t> shape;
    uint64_t start;
    uint64_t size;
    uint64_t padding_previous;
};

static bool allocate_memory_for_pointers(
        ErlNifEnv *env,
        ERL_NIF_TERM list,
        struct c_struct_layout * layout,
        ERL_NIF_TERM &error,
        std::vector<std::pair<void *, size_t>> &list_allocated_ptr,
        std::vector<ERL_NIF_TERM> &allocated_pointers) {
    // debug
    printf("shape: ");
    for (auto &shape : layout->shape) {
        printf("%llu,", shape);
    }
    printf("\r\n");

    // todo: generate ptr that matches the specs

    bool ok = true;
    // lets save allocated memory ptr and their size in `tmp_allocated_ptr` first
    // if we successfully allocated everything for the `list`
    //   - ok: if elements in list are all binary terms
    //   - ok: if malloc return != nullptr
    // we move elements in `tmp_allocated_ptr` to `list_allocated_ptr`
    std::vector<std::pair<void *, size_t>> tmp_allocated_ptr;
    unsigned len;
    enif_get_list_length(env, list, &len);
    if (len != 0) {
        size_t index = 0;
        ErlNifBinary array_data;
        ERL_NIF_TERM head, tail;
        while (enif_get_list_cell(env, list, &head, &tail)) {
            if (enif_inspect_binary(env, head, &array_data)) {
                void * ptr = malloc(array_data.size);
                if (ptr != nullptr) {
                    memcpy(ptr, array_data.data, array_data.size);
                    tmp_allocated_ptr.push_back(std::make_pair(ptr, array_data.size));
                } else {
                    error = erlang::nif::error(env, "cannot allocate memory for array");
                    ok = false;
                    break;
                }
            }
            list = tail;
            index++;
        }
    }

    if (ok) {
        for (auto &p : tmp_allocated_ptr) {
            // {raw_ptr, size}
            ERL_NIF_TERM raw_resource = enif_make_tuple2(env,
                enif_make_uint64(env, (uint64_t)(uint64_t *)p.first),
                enif_make_uint64(env, p.second)
            );
            list_allocated_ptr.push_back(std::make_pair(p.first, p.second));
            allocated_pointers.push_back(raw_resource);
        }
    } else {
        for (auto &p : tmp_allocated_ptr) {
            free(p.first);
        }
        tmp_allocated_ptr.clear();
    }

    return ok;
}

static bool get_layout(ErlNifEnv *env, ERL_NIF_TERM layout_element, std::vector<struct c_struct_layout> &layouts) {
    bool ok = false;

    unsigned len;
    enif_get_list_length(env, layout_element, &len);
    uint8_t flag = 0;

    if (len == 6) {
        struct c_struct_layout layout;
        ERL_NIF_TERM head, tail;
        while (enif_get_list_cell(env, layout_element, &head, &tail)) {
            if (enif_is_tuple(env, head)) {
                int arity;
                const ERL_NIF_TERM * arr = nullptr;
                if (enif_get_tuple(env, head, &arity, &arr)) {
                    if (arity == 2) {
                        std::string ckey;
                        if (erlang::nif::get_atom(env, arr[0], ckey)) {
                            if (ckey == "shape") {
                                std::vector<uint64_t> shape;
                                std::string nil_shape;
                                if (erlang::nif::get_list(env, arr[1], shape)) {
                                    layout.shape = shape;
                                    flag |= 0b0001;
                                } else if (erlang::nif::get_atom(env, arr[1], nil_shape) && nil_shape == "nil") {
                                    layout.shape = {1};
                                    flag |= 0b0001;
                                } else {
                                    break;
                                }
                            } else if (ckey == "start") {
                                if (erlang::nif::get(env, arr[1], &layout.start)) {
                                    flag |= 0b0010;
                                } else {
                                    break;
                                }
                            } else if (ckey == "size") {
                                if (erlang::nif::get(env, arr[1], &layout.size)) {
                                    flag |= 0b0100;
                                } else {
                                    break;
                                }
                            } else if (ckey == "padding_previous") {
                                if (erlang::nif::get(env, arr[1], &layout.padding_previous)) {
                                    flag |= 0b1000;
                                } else {
                                    break;
                                }
                            }
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }

            layout_element = tail;
        }

        if (flag == 0b1111) {
            layouts.push_back(layout);
            ok = true;
        }
    }

    return ok;
}

static bool get_layout_list(ErlNifEnv *env, ERL_NIF_TERM layout_list, std::vector<struct c_struct_layout> &layouts) {
    bool ok = true;

    unsigned len;
    enif_get_list_length(env, layout_list, &len);

    if (len != 0) {
        ERL_NIF_TERM head, tail;
        while (enif_get_list_cell(env, layout_list, &head, &tail)) {
            if (get_layout(env, head, layouts)) {
                layout_list = tail;
            } else {
                ok = false;
                break;
            }
        }
    }

    return ok;
}

static ERL_NIF_TERM c_struct_to_binary(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 3) return enif_make_badarg(env);

    ERL_NIF_TERM ir = argv[0];
    ERL_NIF_TERM layout_term = argv[1];
    ERL_NIF_TERM struct_size_term = argv[2];
    uint64_t struct_size = 0;
    ErlNifBinary struct_data;
    uint64_t current = 0;
    std::vector<ERL_NIF_TERM> allocated_pointers;

    if (erlang::nif::get_uint64(env, struct_size_term, &struct_size)) {
        unsigned len;
        enif_get_list_length(env, ir, &len);

        if (len != 0) {
            std::vector<struct c_struct_layout> layouts;
            if (!get_layout_list(env, layout_term, layouts)) {
                return erlang::nif::error(env, "cannot get layout");
            }
            // debug
            // for (auto &layout : layouts) {
            //    printf("start: %llu, size: %llu, padding_previous: %llu\r\n", layout.start, layout.size, layout.padding_previous);
            // }

            if (!enif_alloc_binary(struct_size, &struct_data)) {
                return erlang::nif::error(env, "enif_alloc_binary: cannot allocate binary");
            }
            memset(struct_data.data, 0, struct_data.size);

            ERL_NIF_TERM head, tail;

            int index = 0;
            while (enif_get_list_cell(env, ir, &head, &tail)) {
                ErlNifBinary elem;
                std::string atom_term;
                uint8_t * ptr = struct_data.data;
                struct c_struct_layout &current_layout = layouts[index];
                if (enif_inspect_binary(env, head, &elem)) {
                    // << 1, 2, 3, 4>>
                    // in this case, we directly copy the binary to the struct
                    memcpy(ptr + current_layout.start, elem.data, std::min((uint64_t)current_layout.size, (uint64_t)elem.size));
                    current += current_layout.size;
                } else if (enif_is_list(env, head)) {
                    // todo: allocate memory
                    printf("[debug/%d] ptr: struct_size: %llu, current: %llu, size: %zu\r\n", index, struct_size, current, sizeof(void *));
                    ERL_NIF_TERM error;
                    std::vector<std::pair<void *, size_t>> list_allocated_ptr;
                    allocate_memory_for_pointers(env, head, &current_layout, error, list_allocated_ptr, allocated_pointers);
                    current += current_layout.size;
                } else if (erlang::nif::get_atom(env, head, atom_term) && atom_term == "nullptr") {
                    memset(ptr + current_layout.start, 0, current_layout.size);
                    current += current_layout.size;
                }
                ir = tail;
                index++;
            }
            printf("[debug/%d] end: struct_size: %llu, current: %llu\r\n\r\n\r\n", index, struct_size, current);
            fflush(stdout);

            return enif_make_tuple3(env,
                                    enif_make_atom(env, "ok"),
                                    enif_make_binary(env, &struct_data),
                                    enif_make_list_from_array(env, nullptr, 0));
        } else {
            if (enif_alloc_binary(0, &struct_data)) {
                return enif_make_tuple3(env,
                                 enif_make_atom(env, "ok"),
                                 enif_make_binary(env, &struct_data),
                                 enif_make_list_from_array(env, nullptr, 0));
            } else {
                return erlang::nif::error(env, "enif_alloc_binary: cannot allocate binary");
            }
        }
    } else {
        return erlang::nif::error(env, "cannot get struct size");
    }
}

static ERL_NIF_TERM c_struct_free(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 1) return enif_make_badarg(env);
    return erlang::nif::error(env, "not implemented yet");
}

static ERL_NIF_TERM c_struct_ptr_size(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    return enif_make_uint64(env, sizeof(void *));
}

static int on_load(ErlNifEnv* env, void**, ERL_NIF_TERM)
{
    return 0;
}

static int on_reload(ErlNifEnv*, void**, ERL_NIF_TERM)
{
    return 0;
}

static int on_upgrade(ErlNifEnv*, void**, void**, ERL_NIF_TERM)
{
    return 0;
}

static ErlNifFunc nif_functions[] = {
    {"to_binary", 3, c_struct_to_binary, 0},
    {"ptr_size", 0, c_struct_ptr_size, 0},
    {"free", 1, c_struct_free, 0},
};

ERL_NIF_INIT(Elixir.CStruct.Nif, nif_functions, on_load, on_reload, on_upgrade, NULL);

#if defined(__GNUC__)
#  pragma GCC visibility push(default)
#endif
