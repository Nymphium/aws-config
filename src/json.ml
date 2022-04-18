exception Invalid_json of Yojson.Safe.t

let get key j =
  match j with
  | `Assoc l ->
    List.assoc_opt key l
    |> Option.map (function
           | `String v -> v
           | _ -> raise @@ Invalid_json j)
  | _ -> raise @@ Invalid_json j
;;

let ( #. ) l k = get k l

let get_exn key j =
  match j with
  | `Assoc l ->
    List.assoc key l
    |> (function
    | `String v -> v
    | _ -> raise @@ Invalid_json j)
  | _ -> raise @@ Invalid_json j
;;

let ( #.! ) l k = get_exn k l
let s3 = "s3"

let get_s3 key = function
  | `Assoc l -> List.assoc_opt s3 l |> Fun.flip Option.bind (get key)
;;

let get_s3_exn key = function
  | `Assoc l -> List.assoc s3 l |> get_exn key
;;
