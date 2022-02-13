#include <erl_nif.h>
#include "nif_utils.hpp"

#ifdef __GNUC__
#  pragma GCC diagnostic ignored "-Wunused-parameter"
#  pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#  pragma GCC diagnostic ignored "-Wunused-variable"
#  pragma GCC diagnostic ignored "-Wunused-function"
#endif

static ERL_NIF_TERM c_struct_to_binary(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 3) return enif_make_badarg(env);

    ERL_NIF_TERM ir = argv[0];
    ERL_NIF_TERM struct_size_term = argv[1];
    uint64_t struct_size = 0;
    ErlNifBinary struct_data;
    uint64_t current = 0;
    std::vector<ERL_NIF_TERM> allocated_pointers;

    if (erlang::nif::get_uint64(env, struct_size_term, &struct_size)) {
        unsigned len;
        enif_get_list_length(env, ir, &len);

        if (len != 0) {
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
                if (enif_inspect_binary(env, head, &elem)) {
                    printf("[debug/%d] binary: struct_size: %llu, current: %llu, size: %zu\r\n", index, struct_size, current, elem.size);
                    memcpy(ptr + current, elem.data, elem.size);
                    current += elem.size;
                } else if (enif_is_list(env, head)) {
                    // todo: allocate memory
                    printf("[debug/%d] ptr: struct_size: %llu, current: %llu, size: %zu\r\n", index, struct_size, current, sizeof(void *));
                    current += sizeof(void *);
                } else if (erlang::nif::get_atom(env, head, atom_term) && atom_term == "nullptr") {
                    printf("[debug/%d] nullptr: struct_size: %llu, current: %llu, size: %zu\r\n", index, struct_size, current, sizeof(void *));
                    memset(ptr + current, 0, sizeof(void *));
                    current += sizeof(void *);
                }
                ir = tail;
                index++;
            }
            printf("[debug/%d] end: struct_size: %llu, current: %llu\r\n\r\n\r\n", index, struct_size, current);
            fflush(stdout);

            return enif_make_binary(env, &struct_data);
        } else {
            if (enif_alloc_binary(0, &struct_data)) {
                return enif_make_binary(env, &struct_data);
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
