CLASS_KW <- "class"
TICK <- "`"
OPEN_CHEV <- "<"
CLOSE_CHEV <- ">"
OPEN_PAREN <- "("
CLOSE_PAREN <- ")"
COMMA <- ","

char_at <- function(str, index) {
  substr(str, index, index)
}

# Idea: turn one of these strings into a list with characters for each parameter type.
#       We will use that type to guide test case generation.
# 
# Example formats:
#
# type `ad.test` <double[], any, ...> => class<`htest`>;
# type `ad.test.pvalue` <double, integer> => double;
# type `ad.test.statistic` <double[]> => double;
#
parse_type <- function(type_string) {
  chev_level <- 0
  in_tick <- FALSE
  done_parameters <- FALSE
  paren_level <- 0
  index <- 1
  last_index <- 1
  last_arrow_index <- 1
  paren_index <- 1
  # clear the 'type ' heading
  type_string <- substring(type_string, 6)
  
  fun_name <- ""
  parameter_types <- c()
  return_type <- ""
  
  # iterate through the string
  while (index <= nchar(type_string)) {
    char_now <- char_at(type_string, index)
    if (char_now == TICK) {
      in_tick <- !in_tick
      if (!in_tick && fun_name == "") {
        # Haven't set the function name yet.
        # +1, -1 to get rid of leading and trailing `
        fun_name <- substring(type_string, last_index + 1, index - 1)
        last_index <- index
      }
    }
    
    if (in_tick) {
      index <- index + 1
      next()
    }
    
    if (char_now == OPEN_CHEV) {
      chev_level <- chev_level + 1
      if (chev_level == 1)
        last_index <- index
    }
    
    if (char_now == CLOSE_CHEV) {
      if (char_at(type_string, index - 1) == "=") {
        # We are actually dealing with the transition to the return type.
        last_index <- index
        last_arrow_index <- index
      } else {
        chev_level <- chev_level - 1
        if (chev_level == 0 && !done_parameters) {
          # We're parsing the last type.
          parameter_types <- c(parameter_types, str_trim(substring(type_string, last_index + 1, index - 1)))
          done_parameters <- TRUE
        }
      }
    }
    
    # At this stage, we are at the "top level" of the type, i.e., we are parsing in the major < ... > top-level angle brackets.
    if (chev_level == 1) {
      if (char_now == COMMA && !done_parameters) {
        # Here, we must have seen a parameter type. 
        # +1, -1 to get rid of leading and trailing crap.
        parameter_types <- c(parameter_types, str_trim(substring(type_string, last_index + 1, index - 1)))
        last_index <- index
      }
    }
    
    # Parsing a return type.
    if (chev_level == 0) {
      if (char_now == "(") {
        paren_level <- paren_level + 1
        paren_index <- index
      } else if (char_now == ")") {
        paren_level <- paren_level - 1
        if (return_type == "") {
          return_type <- str_trim(substring(type_string, paren_index + 1, index - 1))
        }
      } else if (char_now == ";") {
        # We're done. Let's eat whatever we have left as the return type.
        if (return_type == "") {
          return_type <- str_trim(substring(type_string, last_arrow_index + 1, index - 1))
        }
      }
    }
    
    index <- index + 1
  }
  
  list(fun_name = fun_name,
       parameter_types = parameter_types,
       return_type = return_type)
}

# Parse a signature returned by the fuzzer.
#' @export
parse_signature <- function(type_string) {
  chev_level <- 0
  in_chev <- FALSE
  done_parameters <- FALSE
  paren_level <- 0
  index <- 1
  last_index <- 1
  last_arrow_index <- -1
  paren_index <- 1
  
  parameter_types <- c()
  return_type <- ""
  
  # iterate through the string
  while (index <= nchar(type_string)) {
    char_now <- char_at(type_string, index)
    
    if (char_now == OPEN_CHEV) {
      in_chev <- !in_chev
      chev_level <- chev_level + 1
    }
    
    if (char_now == CLOSE_CHEV) {
      if (char_at(type_string, index - 1) == "-") {
        # We are actually dealing with the transition to the return type.
        last_arrow_index <- index
      } else {
        in_chev <- !in_chev
        chev_level <- chev_level - 1
      }
    }
    
    if (in_chev) {
      index <- index + 1
      next()
    }
    
    if (char_now == OPEN_PAREN) {
      paren_level <- paren_level + 1
      if (paren_level == 1) {
        last_index <- index
      }
    }
    
    if (char_now == CLOSE_PAREN) {
      paren_level <- paren_level - 1
      if (paren_level == 0 && !done_parameters) {
        # We're parsing the last type.
        parameter_types <- c(parameter_types, str_trim(substring(type_string, last_index + 1, index - 1)))
        done_parameters <- TRUE
      }
    }
    
    # At this stage, we are at the "top level" of the type, i.e., we are parsing in the major < ... > top-level angle brackets.
    if (paren_level == 1) {
      if (char_now == COMMA && !done_parameters) {
        # Here, we must have seen a parameter type. 
        # +1, -1 to get rid of leading and trailing crap.
        parameter_types <- c(parameter_types, str_trim(substring(type_string, last_index + 1, index - 1)))
        last_index <- index
      }
    }
    
    # Parsing a return type.
    if (paren_level == 0 && last_arrow_index != -1) {
      return_type <- substring(type_string, last_arrow_index + 2)
    }
    
    index <- index + 1
  }
  
  res <- as.list(parameter_types)
  res$return_type <- return_type
  return(res)
}

get_type_for_args_and_ret <- function(args, ret) {
  arg_types <- Map(contractr::infer_type, args)
  ret_type <- contractr::infer_type(ret)
  
  names(arg_types) <- paste0("arg", 1:length(arg_types))
  c(arg_types, c(ret = ret_type))
}

# listOfTypes : list<list<arg1: chr, arg2: chr, ..., arg_ret: chr>>
# Idea: call consolidate_types_to_one on each argument + return.
consolidate_types <- function(listOfTypes, STRAT = c("UoA", "AoU", "HYBRID")[3]) {
  if (length(listOfTypes) == 0)
    return("first argument needs to have stuff")
  
  NUM_ARGS <- length(listOfTypes[[1]])
  
  if (STRAT == "HYBRID") {
    # First, sort by return type.
    # Then, call this again with AoU for each return type.
    
    return_types <- Map(function(lot) {
      lot[[NUM_ARGS]]
    }, listOfTypes) %>% unique
    
    types <- Map(function(rt) {
      lot_for_this_rt <- Filter(function(lot) rt == lot[[NUM_ARGS]], listOfTypes)
      
      type_this_time <- consolidate_types(lot_for_this_rt, STRAT = "AoU")
      
      type_this_time
    }, return_types)
    
    types
  } else if (STRAT == "AoU") {
    # Combine types argument-wise
    
    types_by_arg <- Map(function(i) {
      types_for_arg_i <- Map(function(LoT) {
        LoT[[i]]
      }, listOfTypes)
      
      types_for_arg_i %>% unlist
    }, 1:NUM_ARGS)
    
    types_by_arg
    
    type_by_args <- Map(function(typesForArg) {
      consolidate_types_to_one(typesForArg)
    }, types_by_arg)
    
    type_by_args
  } else if (STRAT == "UoA") {
    # TBH The current implementation of "HYBRID" does this.
  }
}


LGL_SUBTYPE_OF <- c("logical", "integer", "double", "complex")
INT_SUBTYPE_OF <- c("integer", "double", "complex")
DBL_SUBTYPE_OF <- c("double", "complex")
CLX_SUBTYPE_OF <- c("complex")

EASY_SUBTYPES <- list(
  logical = c(LGL_SUBTYPE_OF, paste0("^", LGL_SUBTYPE_OF), paste0(LGL_SUBTYPE_OF, "[]"), paste0("^", LGL_SUBTYPE_OF, "[]")),
  integer = c(INT_SUBTYPE_OF, paste0("^", INT_SUBTYPE_OF), paste0(INT_SUBTYPE_OF, "[]"), paste0("^", INT_SUBTYPE_OF, "[]")),
  double  = c(DBL_SUBTYPE_OF, paste0("^", DBL_SUBTYPE_OF), paste0(DBL_SUBTYPE_OF, "[]"), paste0("^", DBL_SUBTYPE_OF, "[]")),
  complex = c(CLX_SUBTYPE_OF, paste0("^", CLX_SUBTYPE_OF), paste0(CLX_SUBTYPE_OF, "[]"), paste0("^", CLX_SUBTYPE_OF, "[]")),
  `logical[]` = c(paste0(LGL_SUBTYPE_OF, "[]"), paste0("^", LGL_SUBTYPE_OF, "[]")),
  `integer[]` = c(paste0(INT_SUBTYPE_OF, "[]"), paste0("^", INT_SUBTYPE_OF, "[]")),
  `double[]`  = c(paste0(DBL_SUBTYPE_OF, "[]"), paste0("^", DBL_SUBTYPE_OF, "[]")),
  `complex[]` = c(paste0(CLX_SUBTYPE_OF, "[]"), paste0("^", CLX_SUBTYPE_OF, "[]")),
  `^logical` = c(paste0("^", LGL_SUBTYPE_OF), paste0("^", LGL_SUBTYPE_OF, "[]")),
  `^integer` = c(paste0("^", INT_SUBTYPE_OF), paste0("^", INT_SUBTYPE_OF, "[]")),
  `^double`  = c(paste0("^", DBL_SUBTYPE_OF), paste0("^", DBL_SUBTYPE_OF, "[]")),
  `^complex` = c(paste0("^", CLX_SUBTYPE_OF), paste0("^", CLX_SUBTYPE_OF, "[]")),
  `^logical[]` = c(paste0("^", LGL_SUBTYPE_OF, "[]")),
  `^integer[]` = c(paste0("^", INT_SUBTYPE_OF, "[]")),
  `^double[]`  = c(paste0("^", DBL_SUBTYPE_OF, "[]")),
  `^complex[]` = c(paste0("^", CLX_SUBTYPE_OF, "[]")),
  character = c("^character", "character[]", "^character[]"),
  raw = c("^raw", "raw[]", "^raw[]"),
  `character[]` = c("character[]", "^character[]"),
  `raw[]` = c("raw[]", "^raw[]"),
  `^character` = c("^character", "^character[]"),
  `^raw` = c("^raw", "^raw[]"),
  `^character[]` = c("^character[]"),
  `^raw[]` = c("^raw[]")
)

EASY_SUBTYPES_NO_CROSS_SUBTYPING <- list(
  logical = c("logical", "logical[]", "^logical", "^logical[]"),
  integer = c("integer", "integer[]", "^integer", "^integer[]"),
  double  = c("double", "double[]", "^double", "^double[]"),
  complex = c("complex", "complex[]", "^complex", "^complex[]"),
  character = c("^character", "character[]", "^character[]"),
  raw = c("^raw", "raw[]", "^raw[]"),
  `logical[]` = c("logical[]", "^logical[]"),
  `integer[]` = c("integer[]", "^integer[]"),
  `double[]`  = c("double[]", "^double[]"),
  `complex[]` = c("complex[]", "^complex[]"),
  `character[]` = c("character[]", "^character[]"),
  `raw[]` = c("raw[]", "^raw[]"),
  `^logical` = c("^logical", "^logical[]"),
  `^integer` = c("^integer", "^integer[]"),
  `^double`  = c("^double", "^double[]"),
  `^complex` = c("^complex", "^complex[]"),
  `^logical[]` = "^logical[]",
  `^integer[]` = "^integer[]",
  `^double[]`  = "^double[]",
  `^complex[]` = "^complex[]",
  `^character` = c("^character", "^character[]"),
  `^raw` = c("^raw", "^raw[]"),
  `^character[]` = c("^character[]"),
  `^raw[]` = c("^raw[]")
)

# Takes a string s of the form: `name`:type.
# Idea: skip over `...`, find :
split_up_name_type_pairs <- function(s) {
  parsing_name <- FALSE
  
  for (i in 1:nchar(s)) {
    the_char <- substr(s, i, i)
    
    if (the_char == "`") {
      parsing_name <- !parsing_name
    } else if (the_char == ":" && !parsing_name) {
      # This is the one we want.
      return(c(substr(s, 1, i-1), substr(s, i+1, nchar(s))))
    }
  }
  
  c()
}

is_tuple_subtype <- function(t1, t2) {
  if (substr(t1, 1, 4) != substr(t2, 1, 4))
    return(FALSE)
  else if (substr(t1, 1, 4) != "list") {
    return(FALSE)
  }
  
  t1s <- split_up_struct_names_and_types(t1)
  t2s <- split_up_struct_names_and_types(t2)
  
  if (length(t1s) != length(t2s))
    return(FALSE)
  
  # By now, if we haven't returned, they are both tuples.
  # Tuples will not have width subtying, but will have depth.
  # TODO: should it have depth?
  map2(t1s, t2s, is_subtype) %>% reduce(`&&`, .init = TRUE)
}

is_struct_subtype <- function(t1, t2, primitive_subtyping=TRUE) {
  if (substr(t1, 1, 2) != substr(t2, 1, 2))
    return(FALSE)
  # else if (substr(t1, 1, 2) != "{{") {
  else if (substr(t1, 1, 2) != "st") {
    return(FALSE)
  } 
  
  t1s <- split_up_names_and_types(t1)
  t2s <- split_up_names_and_types(t2)
  
  is_width_and_depth_subtype(t1s, t2s, primitive_subtyping=primitive_subtyping)
}

is_list_subtype <- function(t1, t2, primitive_subtyping=TRUE) {
  if (substr(t1, 1, 2) != substr(t2, 1, 2))
    return(FALSE)
  # else if (substr(t1, 1, 2) != "((" && substr(t1, 1, 2) != "[[") {
  else if (substr(t1, 1, 2) != "li" && substr(t1, 1, 2) != "tu") {
    return(FALSE)
  }
  
  # TODO: There has to be a more efficient way to do this.
  t1s <- split_up_names_and_types(t1)
  t2s <- split_up_names_and_types(t2)
  
  is_width_and_depth_subtype(t1s, t2s, primitive_subtyping=primitive_subtyping)
}

is_width_and_depth_subtype <- function(t1s, t2s, primitive_subtyping=TRUE) {
  # First of all, if t2 has any names that t1 doesn't, it's not a subtype.
  # t1 has to have at least everything in t2.
  # Width subtyping.
  if (!reduce(names(t2s) %in% names(t1s), .init=TRUE, `&&`)) {
    return(FALSE)
  }
  
  # Generally, if the first is shorter, that's bad.
  if (length(t1s) < length(t2s))
    return(FALSE)
  
  # Ok. By now we know that t1 has all of t2's names.
  # Depth subtyping time!
  # IF THERE ARE NAMES:
  
  if (!is.null(names(t1s)) && !is.null(names(t2s))) {
    
    for (t2n in names(t2s)) {
      
      # This catches cases where not all of the struct elements are named.
      # It handles NA and "", which may be introduced as part of the
      # data processing pipeline (as part of sanitization).
      if (is.na(t2n) | t2n == "")
        next()
      
      if (!is_subtype(t1s[[t2n]], t2s[[t2n]], primitive_subtyping=primitive_subtyping))
        return(FALSE)
    }
  } else { 
    # Names are NULL, proceed elementwise.
    for (i in 1:min(length(t1s), length(t2s))) {
      if (!is_subtype(t1s[[i]], t2s[[i]], primitive_subtyping=primitive_subtyping))
        return(FALSE)
    }
  }
  
  # If we get to this point, we've exhausted all possible issues.
  TRUE
}


is_subtype <- function(t1, t2, primitive_subtyping=TRUE) {
  # In some cases, dispatched functions don't pick up on outer functions
  # having a vararg. Either way, if one of the types we are consolidating
  # is ..., let's subsume all others.
  # Actually, this shouldn't happen.
  # Counting "..." as any, to absorb dispatch weirdness.
  if (t2 == "any" || t2 == "..." || t2 == "unused" || t2 == "missing" || t1 == t2) { # || t2 == "...") { 
    return(TRUE)
  } 
  
  # If t2 is ? t2', then we want to compare t1 to t2' (as NULL-ness of )
  if (substr(t2, 1, 2) == "? ") {
    t2 <- substr(t2, 3, nchar(t2))
  }
  
  if (t1 == t2) {
    TRUE
  } else if (primitive_subtyping & t1 %in% names(EASY_SUBTYPES)) {
    t2 %in% EASY_SUBTYPES[[t1]]
  } else if (!primitive_subtyping & t1 %in% names(EASY_SUBTYPES)) {
    t2 %in% EASY_SUBTYPES_NO_CROSS_SUBTYPING[[t1]]
  } else if (substr(t1, 1, 2) == "li" || substr(t1, 1, 2) == "tu") {
    is_list_subtype(t1, t2, primitive_subtyping=primitive_subtyping)
    # } else if (substr(t1, 1, 2) == "{{") {
  } else if (substr(t1, 1, 2) == "st") {
    is_struct_subtype(t1, t2, primitive_subtyping=primitive_subtyping)
  } else {
    FALSE
  }
}


unify_class_types <- function(lot) {
  types <- substr(lot, 7, nchar(lot) - 1)
  class_names <- strsplit(types, split=", ", fixed=T) %>% reduce(c, .init = c()) %>% unique
  paste0("class<", paste(class_names, collapse=", "), ">")
}

unify_structs_lists_and_tuples <- function(lot) {
  # The idea with this function is to take many struct, list, and tuple types
  # and consolidate them into their logical supertype.
  # General idea: structs and tuples exist only when they are used consistently.
  # So, we want to promote them to a list type when consistency is lost.
  # Roughly, the rules are as follows:
  # unify(tuple, list) => list
  # unify(struct, list) => list
  # unify(struct, tuple) => list
  # unify(struct<a, b>, struct<a, c>) => struct<a>
  # unify(struct<a>, struct<b>) => list
  # Three-pronged approach.
  # 1. Top level types:
  # a. Pick out the lists first, we deal with them separately.
  lists_only <- lot[substr(lot, 1, 4) == "list"]
  tas <- lot[substr(lot, 1, 4) != "list"]
  
  # Ignore empty lists, structs, and tuples?
  lists_only <- lists_only[lists_only != "list<>"]
  tas <- tas[tas != "struct<>" & tas != "tuple<>"]
  
  if (length(lists_only) == 0 && length(tas) == 0) {
    return("list<any>") # make this list<> if we leave tuples behind
  }
  
  # b. If there are any lists, we just want the types from the non-list elements to try to make a smart
  #    overall type.
  if (length(lot) == 1) {
    lot
  } else if (length(lists_only) > 0 && length(tas) > 0) {
    # Get types from tas.
    tas_types <- map(tas, function(t) split_up_names_and_types(t) %>% unname)
    # And also from the lists.
    l_types <- map(lists_only, split_up_names_and_types) %>% unlist
    
    # We should consolidate all of these types into one.
    descriptive_type <- consolidate_types_to_one(c(reduce(tas_types, c, .init = c()), l_types))
    
    # Finally, return.
    paste0("list<", descriptive_type, ">")
  } else if (length(lists_only) > 0 && length(tas) == 0) {
    # There were lists, and no structs.
    l_types <- map(lists_only, split_up_struct_names_and_types) %>% unlist
    
    # We should consolidate all of these types into one.
    descriptive_type <- consolidate_types_to_one(l_types)
    
    # Finally, return.
    paste0("list<", descriptive_type, ">")
  } else if (length(lists_only) == 0 && length(tas) > 0) {
    # Final case, where there are no big lists, only structs and tuples.
    # First, deal with case where there are tuples and structs.
    tuples <- tas[substr(tas, 1, 5) == "tuple"]
    structs <- tas[substr(tas, 1, 6) == "struct"]
    
    if (length(tuples) > 0 && length(structs) > 0) {
      # There are both.
      tuple_types <- map(tuples, split_up_names_and_types)
      struct_types <- map(structs, function(t) split_up_names_and_types(t) %>% unname)
      
      descriptive_type <- consolidate_types_to_one(c(reduce(tuple_types, c, .init = c()), reduce(struct_types, c, .init = c())))
      
      # We could do more sophisticated processing here, but the intent with tuples and structs was that
      # they would be used consistently. We're just going to produce a list type here.
      paste0("list<", descriptive_type, ">")
    } else if (length(tuples) > 0 && length(structs) == 0) {
      # Just tuples.
      tuple_types <- map(tuples, split_up_names_and_types)
      
      # If they all have the same length, we could try elementwise composition, provided that the types are somewhat compatible.
      # But maybe we punt on that for now.
      descriptive_type <- consolidate_types_to_one(reduce(tuple_types, c, .init = c()))
      
      paste0("list<", descriptive_type, ">")
    } else if (length(tuples) == 0 && length(structs) > 0) {
      # The final case, only structs here. 
      # We have a few unification strategies in mind. We would like elementwise type consolidation (for similar names),
      # and taking a superset of the names.
      struct_names_and_types <- map(structs, function(t) split_up_names_and_types(t))
      
      # Grab common names.
      common_names <- map(struct_names_and_types, names) %>% reduce(intersect)
      
      # If there are *no* common names, we want to do something special, and say it's just a list with the most appropriate type:
      if (length(common_names) == 0) {
        descriptive_type <- consolidate_types_to_one(reduce(struct_names_and_types %>% map(unname), c, .init = c()))
        paste0("list<", descriptive_type, ">")
      } else {
        # Reduce struct_names_and_types to only those in the common names.
        struct_names_and_types <- map(struct_names_and_types, function(l) l[names(l) %in% common_names])
        
        new_struct <- c()
        # Name-wise, let's consolidate the types.
        for (n in common_names) {
          # For each struct in struct_names_and_types, get the relevant name, consolidate.
          name_types <- map(struct_names_and_types, function(s) s[n]) %>% unlist %>% unname
          the_type <- consolidate_types_to_one(name_types)
          new_struct <- c(new_struct, structure(the_type, names=n))
        }
        
        # Remove empty names...
        new_struct <- new_struct[names(new_struct) != ""]
        
        the_names <- names(new_struct)
        new_struct <- new_struct %>% unname
        
        paste0("struct<", map2(the_names, new_struct, function(n, t) { paste0(n, ":", t) }) %>% paste(collapse=", "), ">")
      }
    }
  }
}

remove_redundant_types <- function(lot, primitive_subtyping=TRUE) {
  lot <- unique(lot)
  
  # For each type t1 in lot, if \exists another type t2 in lot s.t. t1 <: t2 and t1 <> t2, remove t1.
  # This is so slow. Is there a better way to do this, to speed it up?
  subtypes <- map(lot, function(t1) {
    map(lot, function(t2) {
      t1 != t2 && is_subtype(t1, t2, primitive_subtyping=primitive_subtyping)
    }) %>% reduce(`||`, .init = FALSE)
  }) %>% unlist
  
  # %>% unique gets rid of unwanted duplicates.
  lot[!subtypes] %>% unique
}

LIST_UNION_HEURISTIC = 5

# Call on every arg.
consolidate_types_to_one <- function(lot, max_num_types = LIST_UNION_HEURISTIC, is_return=FALSE, unify_lists=TRUE, primitive_subtyping=TRUE) {
  lot <- lot[!is.na(lot)]
  
  # There are no non-NAs if this is true.
  if (length(lot) == 0)
    return(NA)
  
  # Do subtyping first. In case we have e.g. list of integers and doubles.
  trimmed_types <- remove_redundant_types(lot, primitive_subtyping=primitive_subtyping)
  
  # Short-circuit for only 1 thing.
  if (length(trimmed_types) == 1)
    return(trimmed_types[[1]])
  
  if (unify_lists) {
    # Ok. Let's unify lists and structs and tuples.
    # First, move the list types out.
    substrs <- substr(trimmed_types, 1, 4)
    lst_types <- trimmed_types[substrs == "stru" | substrs == "list" | substrs == "tupl"]
    # For classes:
    trimmed_types <- trimmed_types[! (substrs == "stru" | substrs == "list" | substrs == "tupl")]
    
    # Next, unify the list types, and add them back.
    if (length(lst_types) > 0) { 
      unified_list_type <- unify_structs_lists_and_tuples(lst_types)
      trimmed_types <- c(trimmed_types, unified_list_type)
    }
    
  }
  
  if (is_return) {
    if (length(trimmed_types) > 1)
      paste0("(", paste(trimmed_types, collapse=" | "), ")")
    else
      paste(trimmed_types, collapse=" | ")
  } else {
    paste(trimmed_types, collapse=" | ")
  }
}

print_signatures_from_df <- function(df) {
  df %>% filter(n_warn + n_err == 0) %>% 
    select(starts_with("arg") & !ends_with("_v"), ret) %>% 
    apply(FUN=function(row) {
      paste(paste(row[1:(length(row)-1)], collapse=", "), "->", row[[length(row)]])
    }, MARGIN=1)
}

# Missing function from the Types for R OOPSLA'20 Artifact.
split_up_names_and_types <- function(t) {
  
  # For dealing with `names`
  parsing_name <- FALSE
  
  # Trim leading and trailing brackets.
  # t <- substr(t, 3, nchar(t) - 2)
  # Trim leading and trailing stuff.
  if (substr(t, 1, 2) == "st") {
    t <- substr(t, 8, nchar(t) - 1)
  } else if (substr(t, 1, 2) == "li") {
    t <- substr(t, 6, nchar(t) - 1)
  } else if (substr(t, 1, 2) == "tu") {
    t <- substr(t, 7, nchar(t) - 1)
  }
  
  # How many levels (outside of the first 2) ((, [[, {{ are we in?
  nest_level <- 0
  last_char <- ""
  
  colon_indices <- c()
  comma_indices <- c(1)
  
  for (i in 1:nchar(t)) {
    this_char <- substr(t, i, i)
    
    if (this_char == "`")
      parsing_name <- !parsing_name
    
    if (!parsing_name) {
      if (this_char == "s" && substr(t, i, i+5) == "struct") {
        nest_level <- nest_level + 1
      } else if (this_char == ">" && last_char != "=") {
        nest_level <- nest_level - 1
      } else if (this_char == "l" && substr(t, i, i+3) == "list") {
        nest_level <- nest_level + 1
      } else if (this_char == "t" && substr(t, i, i+4) == "tuple") {
        nest_level <- nest_level + 1
      } else if (nest_level == 0 && this_char == ":") {
        # here, we are at the top level
        colon_indices <- c(colon_indices, i)
      } else if (nest_level == 0 && this_char == ",") {
        comma_indices <- c(comma_indices, i)
      }
    }
    last_char <- this_char
  }
  
  comma_indices <- c(comma_indices, nchar(t) + 1)
  
  # take indices and make lists of name:type pairs
  # deal with one edge case:
  if (is.null(comma_indices)) {
    name <- substr(t, 1, colon_indices[1] - 1)
    type <- substr(t, colon_indices[1] + 1, nchar(t))
    
    names(type) <- c(name)
    type
    
    # deal with case where its a list with no names
  } else if (is.null(colon_indices)) {
    types <- c()
    
    # hack for dealing with fact that we need to, most of the time, account for ", " separator.
    comma_indices[1] <- -1
    for (i in 1:(length(comma_indices)-1)) {
      # + 2 for the fact that the sep is ", "
      types <- c(types, substr(t, comma_indices[i] + 2, comma_indices[i+1] - 1))
    }
    
    types
  } else {
    names <- c()
    types <- c()
    comma_indices[1] <- comma_indices[1] - 2
    for (i in 1:(length(colon_indices))) {
      names <- c(names, substr(t, comma_indices[i] + 2, colon_indices[i] - 1))
      types <- c(types, substr(t, colon_indices[i] + 1, comma_indices[i+1] - 1))
    }
    
    names(types) <- names
    types
  }
}

# For splitting structs up.
split_up_struct_names_and_types <- function(t) {
  num_l <- 0
  num_b <- 0
  
  parsing_name <- FALSE
  
  indices <- c()
  
  for (i in 1:nchar(t)) {
    this_char <- substr(t, i, i)
    
    if (this_char == "`")
      parsing_name <- !parsing_name
    
    if (!parsing_name) {
      if (num_l == 0 && this_char == "<") {
        indices <- c(indices, i)
      }
      
      if (this_char == "<") {
        num_l <- num_l + 1
      } else if (this_char == ">") {
        num_l <- num_l - 1 # matching
        
        if (num_l == 0) {
          # here, we are done
          indices <- c(indices, i)
          break
        }
      } else if (num_l == 1 && num_b == 0 && this_char == "~") {
        # here, we are at the top level
        indices <- c(indices, i)
      } else if (this_char == "[") {
        num_b <- num_b + 1
      } else if (this_char == "]") {
        num_b <- num_b - 1
      }
    }
  }
  
  # take indices and make lists of name:type pairs
  r <- c()
  for (i in 1:(length(indices)-1)) {
    r <- c(r, substr(t, indices[i] + 1, indices[i+1] - 1))
  }
  
  # return    
  r
}

# measure the complexity of a type signature
# by counting the number of atomic types in it
sig_complexity <- function(t) {
  n <- length(t) # nb of args + return value
  
  sum(map_int(t, ~ 1L + str_count(., pattern = fixed("|")))) / n
}
