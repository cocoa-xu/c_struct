#pragma once

#include "erl_nif.h"
#include <stdarg.h>
#include <map>
#include <string>
#include <vector>

#define GET(ARGN, VAR)                      \
  if (!erlang::nif::get(env, argv[ARGN], &VAR)) \
    return erlang::nif::error(env, "Unable to get " #VAR " param.");

#define PARAM(ARGN, TYPE, VAR) \
  TYPE VAR;                    \
  GET(ARGN, VAR)

#define ATOM_PARAM(ARGN, VAR)                   \
  std::string VAR;                              \
  if (!erlang::nif::get_atom(env, argv[ARGN], VAR)) \
    return erlang::nif::error(env, "Unable to get " #VAR " atom param.");

#define TUPLE_PARAM(ARGN, TYPE, VAR)                 \
  TYPE VAR;                                          \
  if (!erlang::nif::get_tuple(env, argv[ARGN], VAR))  {  \
    std::ostringstream msg;                          \
    msg << "Unable to get " #VAR " tuple param in NIF." << __func__ << "/" << argc; \
    return erlang::nif::error(env, msg.str().c_str());    \
  }

#define LIST_PARAM(ARGN, TYPE, VAR)             \
  TYPE VAR;                                      \
  if (!erlang::nif::get_list(env, argv[ARGN], VAR)) \
    return erlang::nif::error(env, "Unable to get " #VAR " list param.");

#define BINARY_PARAM(ARGN, VAR)                    \
  ErlNifBinary VAR;                                \
  if (!enif_inspect_binary(env, argv[ARGN], &VAR)) \
    return erlang::nif::error(env, "Unable to get " #VAR " binary param.");

namespace erlang
{
  namespace nif
  {
    // Status helpers

    // Helper for returning `{:error, msg}` from NIF.
    ERL_NIF_TERM error(ErlNifEnv *env, const char *msg)
    {
      ERL_NIF_TERM atom = enif_make_atom(env, "error");
      ERL_NIF_TERM reason;
      unsigned char * ptr;
      size_t len = strlen(msg);
      if ((ptr = enif_make_new_binary(env, len, &reason)) != nullptr) {
        strcpy((char *)ptr, msg);
        return enif_make_tuple2(env, atom, reason);
      } else {
        ERL_NIF_TERM msg_term = enif_make_string(env, msg, ERL_NIF_LATIN1);
        return enif_make_tuple2(env, atom, msg_term);
      }
    }

    // Helper for returning `{:ok, term}` from NIF.
    ERL_NIF_TERM ok(ErlNifEnv *env)
    {
      return enif_make_atom(env, "ok");
    }

    // Helper for returning `:ok` from NIF.
    ERL_NIF_TERM ok(ErlNifEnv *env, ERL_NIF_TERM term)
    {
      return enif_make_tuple2(env, ok(env), term);
    }

    // Numeric types
      int get_sint(ErlNifEnv *env, ERL_NIF_TERM term, int *var)
      {
          if (enif_get_int(env, term, reinterpret_cast<int *>(var))) {
              return 1;
          } else {
              ErlNifSInt64 s64;
              if (enif_get_int64(env, term, reinterpret_cast<ErlNifSInt64 *>(&s64))) {
                  *var = (int)(s64);
                  return 1;
              }
          }
          return 0;
      }

      int get_sint64(ErlNifEnv *env, ERL_NIF_TERM term, int64_t *var)
      {
          return enif_get_int64(env, term, reinterpret_cast<ErlNifSInt64 *>(var));
      }

      int get_uint(ErlNifEnv *env, ERL_NIF_TERM term, unsigned int *var)
      {
          if (enif_get_uint(env, term, reinterpret_cast<unsigned int *>(var))) {
              return 1;
          } else {
              int sint;
              if (enif_get_int(env, term, reinterpret_cast<int *>(&sint))) {
                  *var = sint;
                  return 1;
              }
          }
          return 0;
      }

      int get_uint64(ErlNifEnv *env, ERL_NIF_TERM term, uint64_t *var)
      {
          return enif_get_uint64(env, term, reinterpret_cast<ErlNifUInt64 *>(var));
      }

      int get_f64(ErlNifEnv *env, ERL_NIF_TERM term, double *var)
      {
          if (enif_get_double(env, term, var)) {
              return 1;
          } else {
              uint64_t u64;
              int64_t s64;
              int s32;
              unsigned int u32;
              if (get_uint64(env, term, &u64)) {
                  *var = (double)u64;
                  return 1;
              } else if (get_sint64(env, term, &s64)) {
                  *var = (double)s64;
                  return 1;
              } else if (get_uint(env, term, &u32)) {
                  *var = (double)u32;
                  return 1;
              } else if (get_sint(env, term, &s32)) {
                  *var = (double)s32;
                  return 1;
              }
          }
          return 0;
      }

      int get(ErlNifEnv *env, ERL_NIF_TERM term, int *var)
      {
          return enif_get_int(env, term, reinterpret_cast<int *>(var));
      }

      int get(ErlNifEnv *env, ERL_NIF_TERM term, unsigned int *var)
      {
          if (enif_get_uint(env, term, reinterpret_cast<unsigned int *>(var))) {
              return 1;
          } else {
              int sint;
              if (enif_get_int(env, term, reinterpret_cast<int *>(&sint))) {
                  *var = sint;
                  return 1;
              }
          }
          return 0;
      }

      int get(ErlNifEnv *env, ERL_NIF_TERM term, uint64_t *var)
      {
          return enif_get_uint64(env, term, reinterpret_cast<ErlNifUInt64 *>(var));
      }

      int get(ErlNifEnv *env, ERL_NIF_TERM term, int64_t *var)
      {
          return enif_get_int64(env, term, reinterpret_cast<ErlNifSInt64 *>(var));
      }

    int get(ErlNifEnv *env, ERL_NIF_TERM term, double *var)
    {
      return enif_get_double(env, term, var);
    }

    // Standard types

    int get(ErlNifEnv *env, ERL_NIF_TERM term, std::string &var)
    {
      unsigned len;
      int ret = enif_get_list_length(env, term, &len);

      if (!ret)
      {
        ErlNifBinary bin;
        ret = enif_inspect_binary(env, term, &bin);
        if (!ret)
        {
          return 0;
        }
        var = std::string((const char *)bin.data, bin.size);
        return ret;
      }

      var.resize(len + 1);
      ret = enif_get_string(env, term, &*(var.begin()), var.size(), ERL_NIF_LATIN1);

      if (ret > 0)
      {
        var.resize(ret - 1);
      }
      else if (ret == 0)
      {
        var.resize(0);
      }
      else
      {
      }

      return ret;
    }

    ERL_NIF_TERM make(ErlNifEnv *env, bool var)
    {
      if (var)
        return enif_make_atom(env, "true");

      return enif_make_atom(env, "false");
    }

    ERL_NIF_TERM make(ErlNifEnv *env, long var)
    {
      return enif_make_int64(env, var);
    }

    ERL_NIF_TERM make(ErlNifEnv *env, int var)
    {
      return enif_make_int(env, var);
    }

    ERL_NIF_TERM make(ErlNifEnv *env, double var)
    {
      return enif_make_double(env, var);
    }

    ERL_NIF_TERM make(ErlNifEnv *env, ErlNifBinary var)
    {
      return enif_make_binary(env, &var);
    }

    ERL_NIF_TERM make(ErlNifEnv *env, std::string var)
    {
      return enif_make_string(env, var.c_str(), ERL_NIF_LATIN1);
    }

    ERL_NIF_TERM make(ErlNifEnv *env, const char *string)
    {
      return enif_make_string(env, string, ERL_NIF_LATIN1);
    }

    // Atoms

    int get_atom(ErlNifEnv *env, ERL_NIF_TERM term, std::string &var)
    {
      unsigned atom_length;
      if (!enif_get_atom_length(env, term, &atom_length, ERL_NIF_LATIN1))
      {
        return 0;
      }

      var.resize(atom_length + 1);

      if (!enif_get_atom(env, term, &(*(var.begin())), var.size(), ERL_NIF_LATIN1))
        return 0;

      var.resize(atom_length);

      return 1;
    }

    ERL_NIF_TERM atom(ErlNifEnv *env, const char *msg)
    {
      return enif_make_atom(env, msg);
    }

    // Check if :nil
    int check_nil(ErlNifEnv *env, ERL_NIF_TERM term) {
        std::string atom_str;
        if (get_atom(env, term, atom_str) && atom_str == "nil") {
            return true;
        }
        return false;
    }

    // Boolean

    int get(ErlNifEnv *env, ERL_NIF_TERM term, bool *var)
    {
      std::string bool_atom;
      if (!get_atom(env, term, bool_atom))
        return 0;
      *var = (bool_atom == "true");
      return 1;
    }

    // Containers

    int get_tuple(ErlNifEnv *env, ERL_NIF_TERM tuple, std::vector<int64_t> &var)
    {
      const ERL_NIF_TERM *terms;
      int length;
      if (!enif_get_tuple(env, tuple, &length, &terms))
        return 0;
      var.reserve(length);

      for (int i = 0; i < length; i++)
      {
        int data;
        if (!get(env, terms[i], &data))
          return 0;
        var.push_back(data);
      }
      return 1;
    }

    int get_list(ErlNifEnv *env,
                 ERL_NIF_TERM list,
                 std::vector<ErlNifBinary> &var)
    {
      unsigned int length;
      if (!enif_get_list_length(env, list, &length))
        return 0;
      var.reserve(length);
      ERL_NIF_TERM head, tail;

      while (enif_get_list_cell(env, list, &head, &tail))
      {
        ErlNifBinary elem;
        if (!enif_inspect_binary(env, head, &elem))
          return 0;
        var.push_back(elem);
        list = tail;
      }
      return 1;
    }

    int get_list(ErlNifEnv *env,
                 ERL_NIF_TERM list,
                 std::vector<std::string> &var)
    {
      unsigned int length;
      if (!enif_get_list_length(env, list, &length))
        return 0;
      var.reserve(length);
      ERL_NIF_TERM head, tail;

      while (enif_get_list_cell(env, list, &head, &tail))
      {
        std::string elem;
        if (get_atom(env, head, elem) || get(env, head, elem)) {
            var.push_back(elem);
            list = tail;
        } else {
            return 0;
        }
      }
      return 1;
    }

    int get_list(ErlNifEnv *env, ERL_NIF_TERM list, std::vector<uint64_t> &var)
    {
      unsigned int length;
      if (!enif_get_list_length(env, list, &length))
        return 0;
      var.reserve(length);
      ERL_NIF_TERM head, tail;

      while (enif_get_list_cell(env, list, &head, &tail))
      {
        uint64_t elem;
        if (!get(env, head, &elem))
          return 0;
        var.push_back(elem);
        list = tail;
      }
      return 1;
    }

    int get_list(ErlNifEnv *env, ERL_NIF_TERM list, std::vector<int64_t> &var)
    {
      unsigned int length;
      if (!enif_get_list_length(env, list, &length))
        return 0;
      var.reserve(length);
      ERL_NIF_TERM head, tail;

      while (enif_get_list_cell(env, list, &head, &tail))
      {
        int64_t elem;
        if (!get(env, head, &elem))
          return 0;
        var.push_back(elem);
        list = tail;
      }
      return 1;
    }

    inline int allowed_spec(char t) {
        return (t == 's' || t == 'b' || t == 'h' || t == 'i' || t == 'I' || t == 'l' || t == 'L' \
                || t == 'k' || t == 'K' || t == 'n' || t == 'f' || t == 'd' || t == 'O');
    }

    inline int parse_arg(ErlNifEnv *env, int opt_arg_index, const ERL_NIF_TERM * argv, std::map<std::string, ERL_NIF_TERM>& erl_terms) {
        ERL_NIF_TERM opts = argv[opt_arg_index];
        if (enif_is_list(env, opts)) {
            unsigned length = 0;
            enif_get_list_length(env, opts, &length);
            unsigned list_index = 0;

            ERL_NIF_TERM term, rest;
            while (list_index != length) {
                enif_get_list_cell(env, opts, &term, &rest);

                if (enif_is_tuple(env, term)) {
                    int arity;
                    const ERL_NIF_TERM * arr = nullptr;
                    if (enif_get_tuple(env, term, &arity, &arr)) {
                        if (arity == 2) {
                            std::string ckey;
                            if (get_atom(env, arr[0], ckey)) {
                                erl_terms[ckey] = arr[1];
                            }
                        }
                    }
                }
                list_index++;
                opts = rest;
            }
            return true;
        }
        return false;
    }
  }
}
