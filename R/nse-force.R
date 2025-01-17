#' Inject objects inside expressions
#'
#' @description
#'
#' It is sometimes useful to inject language objects or other kinds of
#' objects inside an expression before it gets fully evaluated. The
#' tidy eval framework provides several injection operators for
#' different use cases.
#'
#' - The injection operator `!!` (pronounced "bang-bang") injects a
#'   _single_ object. One common case for `!!` is to substitute an
#'   environment-variable (created with `<-`) with a data-variable
#'   (inside a data frame).
#'
#'   ```
#'   library(dplyr)
#'
#'   # The env-variable `var` contains a symbol object, in this
#'   # case a reference to the data-variable `height`
#'   var <- sym("height")
#'
#'   # We inject the data-variable contained in `var` inside `summarise()` 
#'   starwars %>%
#'     summarise(avg = mean(!!var, na.rm = TRUE))
#'   ```
#'
#' - The big-bang operator `!!!` injects a _list_ of objects. Whereas
#'   `!!` would inject the list itself, `!!!` injects each element of
#'   the list in turn. This is also called "splicing".
#'
#'   ```
#'   vars <- syms(c("height", "mass"))
#'
#'   # Injecting with `!!!` is equivalent to supplying the elements separately
#'   starwars %>% select(!!!vars)
#'   starwars %>% select(height, mass)
#'   ```
#'
#' - The injection operator `{{ }}` (pronounced "curly-curly") is made
#'   specially for function arguments. It [defuses][nse-defuse] the
#'   argument and immediately injects it in place. The injected
#'   argument can then be evaluated in another context like a data
#'   frame.
#'
#'   ```
#'   # Inject function arguments that might contain
#'   # data-variables by embracing them with {{ }}
#'   mean_by <- function(data, by, var) {
#'     data %>%
#'       group_by({{ by }}) %>%
#'       summarise(avg = mean({{ var }}, na.rm = TRUE))
#'   }
#'
#'   # The data-variables `Species` and `Sepal.Width` inside the
#'   # env-variables `by` and `var` are injected inside `group_by()`
#'   # and `summarise()`
#'   iris %>% mean_by(by = Species, var = Sepal.Width)
#'   ```
#'
#' Use `qq_show()` to experiment with injection operators. `qq_show()`
#' defuses its input, processes all injection operators, and prints
#' the result with [expr_print()] to reveal the injected objects.
#'
#'
#' @section Injecting names:
#'
#' When a function takes multiple named arguments
#' (e.g. `dplyr::mutate()`), it is difficult to supply a variable as
#' name. Since the LHS of `=` is [defused][nse-defuse], giving the name
#' of a variable results in the argument having the name of the
#' variable rather than the name stored in that variable. This problem
#' of forcing evaluation of names is exactly what the `!!` operator is
#' for.
#'
#' Unfortunately R is very strict about the kind of expressions
#' supported on the LHS of `=`. This is why rlang interprets the
#' walrus operator `:=` as an alias of `=`. You can use it to supply
#' names, e.g. `a := b` is equivalent to `a = b`. Since its syntax is
#' more flexible you can also inject names on its LHS:
#'
#' ```
#' name <- "Jane"
#'
#' list2(!!name := 1 + 2)
#' exprs(!!name := 1 + 2)
#' ```
#'
#' Like `=`, the `:=` operator expects strings or symbols on its LHS.
#'
#' Since unquoting names is related to interpolating within a string
#' with the glue package, we have made the glue syntax available on
#' the LHS of `:=`:
#'
#' ```
#' list2("{name}" := 1)
#' tibble("{name}" := 1)
#' ```
#'
#' You can also interpolate defused function arguments with double
#' braces `{{`, similar to the curly-curly syntax:
#'
#' ```
#' wrapper <- function(data, var) {
#'   data %>% mutate("{{ var }}_foo" := {{ var }} * 2)
#' }
#' ```
#'
#' Currently, injecting names with `:=` only works in top level
#' expressions. These are all valid:
#'
#' ```
#' exprs("{name}" := x)
#' tibble("{name}" := x)
#' ```
#'
#' But deep-injection of names isn't supported:
#'
#' ```
#' exprs(this(is(deep("{name}" := x))))
#' ```
#'
#'
#' @section Theory:
#'
#' Formally, `quo()` and `expr()` are quasiquotation functions, `!!`
#' is the unquote operator, and `!!!` is the unquote-splice operator.
#' These terms have a rich history in Lisp languages, and live on in
#' modern languages like
#' [Julia](https://docs.julialang.org/en/v1/manual/metaprogramming/)
#' and
#' [Racket](https://docs.racket-lang.org/reference/quasiquote.html).
#'
#' @name bang-bang
#' @aliases quasiquotation UQ UQS {{}} \{\{ nse-force nse-inject
#' @examples
#' # Interpolation with {{  }} is the easiest way to forward
#' # arguments to tidy eval functions:
#' if (is_attached("package:dplyr")) {
#'
#' # Forward all arguments involving data frame columns by
#' # interpolating them within other data masked arguments.
#' # Here we interpolate `arg` in a `summarise()` call:
#' my_function <- function(data, arg) {
#'   summarise(data, avg = mean({{ arg }}, na.rm = TRUE))
#' }
#'
#' my_function(mtcars, cyl)
#' my_function(mtcars, cyl * 10)
#'
#' # The  operator is just a shortcut for `!!enquo()`:
#' my_function <- function(data, arg) {
#'   summarise(data, avg = mean(!!enquo(arg), na.rm = TRUE))
#' }
#'
#' my_function(mtcars, cyl)
#'
#' }
#'
#' # Quasiquotation functions quote expressions like base::quote()
#' quote(how_many(this))
#' expr(how_many(this))
#' quo(how_many(this))
#'
#' # In addition, they support unquoting. Let's store symbols
#' # (i.e. object names) in variables:
#' this <- sym("apples")
#' that <- sym("oranges")
#'
#' # With unquotation you can insert the contents of these variables
#' # inside the quoted expression:
#' expr(how_many(!!this))
#' expr(how_many(!!that))
#'
#' # You can also insert values:
#' expr(how_many(!!(1 + 2)))
#' quo(how_many(!!(1 + 2)))
#'
#'
#' # Note that when you unquote complex objects into an expression,
#' # the base R printer may be a bit misleading. For instance compare
#' # the output of `expr()` and `quo()` (which uses a custom printer)
#' # when we unquote an integer vector:
#' expr(how_many(!!(1:10)))
#' quo(how_many(!!(1:10)))
#'
#' # This is why it's often useful to use qq_show() to examine the
#' # result of unquotation operators. It uses the same printer as
#' # quosures but does not return anything:
#' qq_show(how_many(!!(1:10)))
#'
#'
#' # Use `!!!` to add multiple arguments to a function. Its argument
#' # should evaluate to a list or vector:
#' args <- list(1:3, na.rm = TRUE)
#' quo(mean(!!!args))
#'
#' # You can combine the two
#' var <- quote(xyz)
#' extra_args <- list(trim = 0.9, na.rm = TRUE)
#' quo(mean(!!var , !!!extra_args))
#'
#'
#' # The plural versions have support for the `:=` operator.
#' # Like `=`, `:=` creates named arguments:
#' quos(mouse1 := bernard, mouse2 = bianca)
#'
#' # The `:=` is mainly useful to unquote names. Unlike `=` it
#' # supports `!!` on its LHS:
#' var <- "unquote me!"
#' quos(!!var := bernard, mouse2 = bianca)
#'
#'
#' # All these features apply to dots captured by enquos():
#' fn <- function(...) enquos(...)
#' fn(!!!args, !!var := penny)
#'
#'
#' # Unquoting is especially useful for building an expression by
#' # expanding around a variable part (the unquoted part):
#' quo1 <- quo(toupper(foo))
#' quo1
#'
#' quo2 <- quo(paste(!!quo1, bar))
#' quo2
#'
#' quo3 <- quo(list(!!quo2, !!!syms(letters[1:5])))
#' quo3
NULL

#' @rdname bang-bang
#' @usage NULL
#' @export
UQ <- function(x) {
  abort("`UQ()` can only be used within a quasiquoted argument")
}
#' @rdname bang-bang
#' @usage NULL
#' @export
UQS <- function(x) {
  abort("`UQS()` can only be used within a quasiquoted argument")
}
#' @rdname bang-bang
#' @usage NULL
#' @export
`!!` <- function(x) {
  abort("`!!` can only be used within a quasiquoted argument")
}
#' @rdname bang-bang
#' @usage NULL
#' @export
`!!!` <- function(x) {
  abort("`!!!` can only be used within a quasiquoted argument")
}
#' @rdname bang-bang
#' @usage NULL
#' @export
`:=` <- function(x, y) {
  abort("`:=` can only be used within a quasiquoted argument")
}

#' @rdname bang-bang
#' @param expr An expression to be quasiquoted.
#' @usage NULL
#' @export
qq_show <- function(expr) {
  expr_print(enexpr(expr))
}


glue_unquote <- function(text, env = caller_env()) {
  glue::glue(glue_first_pass(text, env = env), .envir = env)
}
glue_first_pass <- function(text, env = caller_env()) {
  glue::glue(
    text,
    .open = "{{",
    .close = "}}",
    .transformer = glue_first_pass_eval,
    .envir = env
  )
}
glue_first_pass_eval <- function(text, env) {
  text_expr <- parse_expr(text)
  defused_expr <- eval_bare(call2(enexpr, text_expr), env)
  as_label(defused_expr)
}
