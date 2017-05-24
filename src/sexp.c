#include "rlang.h"

SEXP rlang_sxp_address(SEXP x) {
  static char str[1000];
  snprintf(str, 1000, "%p", (void*) x);
  return Rf_mkString(str);
}

SEXP rlang_is_reference(SEXP x, SEXP y) {
  return Rf_ScalarLogical(x == y);
}

void mut_attr(SEXP x, SEXP sym, SEXP attr) {
  Rf_setAttrib(x, sym, attr);
}
void mut_class(SEXP x, SEXP classes) {
  Rf_setAttrib(x, R_ClassSymbol, classes);
}

SEXP set_attr(SEXP x, SEXP sym, SEXP attr) {
  x = PROTECT(Rf_shallow_duplicate(x));
  mut_attr(x, sym, attr);

  UNPROTECT(1);
  return x;
}
SEXP set_class(SEXP x, SEXP classes) {
  return set_attr(x, R_ClassSymbol, classes);
}

SEXP sxp_class(SEXP x) {
  return Rf_getAttrib(x, R_ClassSymbol);
}
SEXP sxp_names(SEXP x) {
  return Rf_getAttrib(x, R_NamesSymbol);
}

void mut_names(SEXP x, SEXP nms) {
  Rf_setAttrib(x, R_NamesSymbol, nms);
}

bool is_named(SEXP x) {
  SEXP nms = sxp_names(x);

  if (TYPEOF(nms) != STRSXP)
    return false;

  if (chr_has(nms, ""))
    return false;

  return true;
}
