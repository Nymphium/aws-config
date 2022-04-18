exception Failed_to_parse_line of string
exception Duplicate_key of string * string
exception Invalid_indentation of string

let re_field = Re.(Pcre.re {|^(\s*)(.+?)\s*=\s*(.*)\s*$|} |> compile)

let strip_comment str =
  let rex = Re.(Pcre.re {|^(.*)\s*#.*$|} |> compile) in
  try (Re.Pcre.extract ~rex str).(1) with
  | Not_found -> str
;;

(** Read entry name: [[entry]] -> ["entry"] *)
let parse_entryname str =
  let rex = Re.(Pcre.re {|^\s*\[(.*)\]\s*$|} |> compile) in
  try (Re.Pcre.extract ~rex str).(1) with
  | Not_found -> raise @@ Failed_to_parse_line str
;;

(** Parse field and indentation depth: [[  key = val]] -> [(2, "key", "val")] *)
let parse_field str =
  try
    let result = Re.Pcre.extract ~rex:re_field str in
    String.length result.(1), result.(2), result.(3)
  with
  | Not_found -> raise @@ Failed_to_parse_line str
;;

(** Parse profile name *)
let parse_profile =
  let rex = Re.(Pcre.re {|profile\s+(.*)|} |> compile) in
  fun str ->
    try Some (Re.Pcre.extract ~rex str).(1) with
    | Not_found -> None
;;

(** Read fields with respect to indentation level for s3 subsection. *)
let rec read_fields
    ?(next_s3 = false)
    ?(in_s3 = false)
    level
    contents
    ((fields, s3_fields) as conf)
  =
  match contents with
  | [] -> conf
  | hd :: tl ->
    let level', key, value = parse_field hd in
    let () =
      if (not next_s3) && level' > level
      then raise @@ Invalid_indentation hd
      else if List.mem_assoc key (if in_s3 then s3_fields else fields)
      then raise @@ Duplicate_key (key, value)
    in
    let next_s3 = String.equal key "s3" in
    let in_s3 = next_s3 || (in_s3 && level' = level) in
    read_fields level' ~next_s3 ~in_s3 tl
    @@
    (match next_s3, in_s3 with
    | false, false -> (key, value) :: fields, s3_fields
    | true, _ -> conf
    | _, true -> fields, (key, value) :: s3_fields)
;;

(** Parse file as AWS config.
    @raise Failed_to_parse_line when the reading line is invalid
    @raise Invalid_indentation when the reading line has invalid indentation
    @raise Duplicate_key when the field key is duplicated
 *)
let parse str =
  let contents =
    String.split_on_char '\n' str
    |> List.filter_map (fun line ->
           match strip_comment line |> String.trim with
           | "" -> None
           | line -> Some line)
  in
  let rec go contents entries =
    match contents with
    | [] -> entries
    | hd :: tl ->
      let name = parse_entryname hd in
      let p, tl = List.partition (Re.Pcre.pmatch ~rex:re_field) tl in
      let fields, s3_fields = read_fields Int.max_int p ([], []) in
      go tl ((name, (fields, s3_fields)) :: entries)
  in
  go contents []
;;
