#' Load the dictionary
#'
#' @param path Path to the dictionary
#' @param ... additional parameters passed to rio::import and its underlying functions.
#' For example the sheet name for an excel file
#'
#' @returns a tibble containing the dictionary
#' 
#' @export
load_dictionary_file <- function(path,...){
  stopifnot(file.exists(path.expand(path)))

  rio::import(path,setclass = "tbl",...) 
}



#' Check for duplicate concept IDs
#'
#' Warn about repeated concept IDs and retain the first row for each ID.
#' Identical ID-definition pairs should be removed before calling this helper
#' if warnings should identify only conflicting definitions.
#'
#' @param df A tibble containing a `concept_id` column.
#' @returns The input with one row per concept ID. When duplicates are found,
#'   the result is ungrouped and ordered by the concept ID groups.
#' @keywords internal
check_cid_for_duplicates <- function(df){
  dup_ids <- df$concept_id[ which(duplicated(df$concept_id) | duplicated(df$concept_id, fromLast = TRUE)) ]
  if (length(dup_ids)>0){
    dup_rows <- df |>
      dplyr::filter(concept_id %in% dup_ids) |>
      dplyr::arrange(concept_id)

    msg <- paste0(
      "Duplicate concept id(s) found:\n",
      "  -- Using the first definition.\n\n",
      paste(capture.output(print(dup_rows,n=Inf)),collapse = "\n")
    )
    warning(msg)
    
    df <- df |> dplyr::group_by(concept_id) |>
      dplyr::slice_head(n=1) |>
        dplyr::ungroup()

    attr(df, "CID_warning") <- dup_rows
  }
  df
}

#' Extract column symbols from a quosure
#'
#' Accept a bare column name or a call to `c()` containing bare column names.
#' Other expressions produce an error.
#'
#' @param q A quosure containing the column selection expression.
#' @returns A list of column symbols.
#' @keywords internal
get_cols <- function(q){
  # get the expression from the quosure
  expr <- rlang::quo_get_expr(q)

  if (rlang::is_call(expr,"c")){
    # if the expression is a c(...) then
    # get the args.  Only accept c(...) all other
    # functions fail.
    cols <- rlang::call_args(expr)
    if (!purrr::every(cols, rlang::is_symbol)) {
      rlang::abort("Columns must be supplied as bare names.")
    }
    cols
  } else if (rlang::is_symbol(expr)){
    list(expr)
  } else{
    rlang::abort("Must be a column name or vector of column")
  }
}

#' Build a concept lookup from dictionary columns
#'
#' Combine paired concept ID and definition columns into a two-column tibble.
#' Column pairs are matched by position and must have equal lengths.
#'
#' @param df A data frame or other object convertible to a tibble containing
#'   the dictionary columns.
#' @param concept_ids Bare concept ID column names, supplied as a single name
#'   or combined with `c()`.
#' @param definitions Bare definition column names, supplied as a single name
#'   or combined with `c()`, in the same order as `concept_ids`.
#' @details Identical ID-definition pairs and rows with missing concept IDs
#'   are removed after combining all column pairs. If an ID has conflicting
#'   definitions, a warning is issued and the first occurrence is retained,
#'   using column-pair order followed by input row order. Missing definitions
#'   are retained and may be selected as the first occurrence. When conflicts
#'   are found, the result is ordered by the concept ID groups.
#' @returns A tibble with `concept_id` and `definitions` columns and one row
#'   per non-missing concept ID. Conflicting definitions are stored in the
#'   `CID_warning` attribute and can be retrieved with [cid_warning()].
#' @export
add_concept_ids <- function(df,concept_ids,definitions){
  df <- tibble::as_tibble(df)
  
  # capture the input 
  cid_quos <- rlang::enquo(concept_ids)
  def_quos <- rlang::enquo(definitions)

  # the columns are a list of symbols...
  cid_cols <- get_cols(cid_quos)
  def_cols <- get_cols(def_quos)

  if (length(cid_cols) != length(def_cols)) {
    rlang::abort("The number of CID columns must equal the number of definitions.")
  } 

  x <- purrr::map2_dfr(cid_cols,def_cols, \(cid,def){
    df |> dplyr::select(!!cid,!!def) |>
      dplyr::rename(concept_id = rlang::as_name(cid),definitions=rlang::as_name(def)) |>
      dplyr::mutate(definitions = sub("^\\d+\\s*=\\s*", "", definitions, perl = TRUE))
    }) |>  dplyr::distinct() |>
      dplyr::filter(!is.na(concept_id)) |>
      check_cid_for_duplicates()

  x
}

#' Retrieve conflicting concept definitions
#'
#' Retrieve the conflict report stored by [add_concept_ids()] without issuing
#' another warning or modifying the lookup.
#'
#' @param df A concept lookup returned by [add_concept_ids()].
#' @returns A tibble with `concept_id` and `definitions` columns containing
#'   the distinct conflicting ID-definition pairs, including the definitions
#'   retained in the lookup. Returns `NULL` if the `CID_warning` attribute
#'   is absent, as when no conflicts were found.
#' @export
cid_warning <- function(df) {
  attr(df, "CID_warning", exact = TRUE)
}

#' Compare values while retaining missing left-hand values
#'
#' Test inequality, treating a missing value in `x` as `TRUE`.
#'
#' @param x,y Vectors to compare using R's usual comparison and recycling rules.
#' @returns A logical vector. Missing values in `x` return `TRUE`; a missing
#'   value in `y` returns `NA` when the corresponding value in `x` is not missing.
#' @keywords internal
`%!=%` <- function(x,y) is.na(x) | x!=y

#' Build a concept dictionary from a file
#'
#' Import a dictionary file with [load_dictionary_file()] and combine selected
#' concept ID and definition columns with [add_concept_ids()].
#'
#' @param path Path to the dictionary file.
#' @param concept_ids Bare concept ID column names, supplied as a single name
#'   or combined with `c()`.
#' @param definitions Bare definition column names, supplied as a single name
#'   or combined with `c()`, in the same order as `concept_ids`.
#' @param ... Additional arguments passed to [load_dictionary_file()] and
#'   ultimately to [rio::import()], such as `sheet` and `col_types` for Excel.
#' @details Column pairs must have equal lengths. Identical ID-definition pairs
#'   and rows with missing concept IDs are removed. Leading numeric value labels
#'   such as `1 = ` are stripped from definitions. Conflicting definitions issue
#'   a warning, and the first occurrence is retained, using column-pair order
#'   followed by input row order. Missing definitions are retained. See
#'   [add_concept_ids()] for details.
#' @returns A tibble with `concept_id` and `definitions` columns and one row per
#'   non-missing concept ID. When conflicts occur, the conflict report is stored
#'   in the `CID_warning` attribute and can be retrieved with [cid_warning()].
#' @examples
#' path <- tempfile(fileext = ".csv")
#' utils::write.csv(
#'   data.frame(
#'     concept_id_1 = c("72841936", "39508271"),
#'     definition_1 = c("Age", "Height"),
#'     concept_id_2 = c("86173409", "54296813"),
#'     definition_2 = c("Weight", "Blood pressure")
#'   ),
#'   path, row.names = FALSE
#' )
#' dictionary <- make_dictionary(
#'   path,
#'   concept_ids = c(concept_id_1, concept_id_2),
#'   definitions = c(definition_1, definition_2),
#'   colClasses = "character"
#' )
#' dictionary
#' unlink(path)
#' @export
make_dictionary <- function(path,concept_ids,definitions,...){
  load_dictionary_file(path,...) |>
    add_concept_ids({{concept_ids}},{{definitions}})
}
