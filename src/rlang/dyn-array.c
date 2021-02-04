#include <rlang.h>
#include "dyn-array.h"

#define R_DYN_ARRAY_GROWTH_FACTOR 2

static
sexp* attribs_dyn_array = NULL;


struct r_dyn_array* r_new_dyn_vector(enum r_type type,
                                     r_ssize capacity) {
  sexp* shelter = KEEP(r_new_list(2));
  r_poke_attrib(shelter, attribs_dyn_array);
  r_mark_object(shelter);

  sexp* vec_raw = r_new_raw(sizeof(struct r_dyn_array));
  r_list_poke(shelter, 0, vec_raw);

  sexp* vec_sexp = r_new_vector(type, capacity);
  r_list_poke(shelter, 1, vec_sexp);

  struct r_dyn_array* p_vec = r_raw_deref(vec_raw);
  p_vec->shelter = shelter;
  p_vec->count = 0;
  p_vec->capacity = capacity;
  p_vec->growth_factor = R_DYN_ARRAY_GROWTH_FACTOR;
  p_vec->v_data = r_vec_deref0(type, vec_sexp);
  p_vec->type = type;
  p_vec->elt_byte_size = r_vec_elt_sizeof0(type);

  FREE(1);
  return p_vec;
}

struct r_dyn_array* r_new_dyn_array(r_ssize elt_byte_size,
                                    r_ssize capacity) {
  r_ssize arr_byte_size = r_ssize_mult(capacity, elt_byte_size);
  return r_new_dyn_vector(r_type_raw, arr_byte_size);
}


void r_arr_push_back(struct r_dyn_array* p_arr, void* p_elt) {
  r_ssize count = ++p_arr->count;
  if (count > p_arr->capacity) {
    r_ssize new_capacity = r_ssize_mult(p_arr->capacity,
                                        p_arr->growth_factor);
    r_arr_resize(p_arr, new_capacity);
  }

  if (p_elt) {
    memcpy(r_arr_ptr_back(p_arr), p_elt, p_arr->elt_byte_size);
  } else {
    memset(r_arr_ptr_back(p_arr), 0, p_arr->elt_byte_size);
  }
}

void r_arr_resize(struct r_dyn_array* p_arr,
                  r_ssize capacity) {
  enum r_type type = p_arr->type;

  sexp* arr_raw = r_vec_resize0(type,
                                r_list_get(p_arr->shelter, 1),
                                p_arr->elt_byte_size * capacity);
  r_list_poke(p_arr->shelter, 1, arr_raw);

  p_arr->count = r_ssize_min(p_arr->count, capacity);
  p_arr->capacity = capacity;
  p_arr->v_data = r_vec_deref0(type, arr_raw);
}


void r_init_library_dyn_array() {
  attribs_dyn_array = r_preserve_global(r_pairlist(r_chr("rlang_dyn_array")));
  r_node_poke_tag(attribs_dyn_array, r_syms_class);
}
