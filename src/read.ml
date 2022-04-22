(** Compose field preferring the rhs. *)
let compose_field l r =
  let acc, r' =
    ListLabels.fold_left l ~init:([], r) ~f:(fun (acc, r') (k, v) ->
        match List.assoc_opt k r' with
        | Some v' ->
          let r' = List.remove_assoc k r' in
          (k, v') :: acc, r'
        | None -> (k, v) :: acc, r')
  in
  acc @ r'
;;

(** Compose config preferring the rhs. *)
let compose_conf l r =
  let acc, r' =
    ListLabels.fold_left
      l
      ~init:([], r)
      ~f:(fun (acc, r') ((name, (field, s3_field)) as entry) ->
        match List.assoc_opt name r' with
        | Some (field', s3_field') ->
          let field' = compose_field field field' in
          let s3_field' = compose_field s3_field s3_field' in
          let r' = List.remove_assoc name r' in
          (name, (field', s3_field')) :: acc, r'
        | None -> entry :: acc, r')
  in
  acc @ r'
;;

(** Convert parsed data to Yojson. *)
let to_yojson (fields, s3_fields) : Yojson.Safe.t =
  let s3_config = "s3", `Assoc (List.map (fun (k, v) -> k, `String v) s3_fields) in
  `Assoc (s3_config :: List.map (fun (k, v) -> k, `String v) fields)
;;

let chunk_file filename =
  let file = open_in filename in
  let len = in_channel_length file in
  let buf = Buffer.create len in
  let () = Buffer.add_channel buf file len in
  let () = close_in file in
  Buffer.contents buf
;;

let merge_profile = function
  | Some prof -> prof
  | None ->
    (match Sys.getenv_opt "AWS_PROFILE" with
    | Some prof -> prof
    | None -> "default")
;;

let upsert_assoc k v l =
  if List.mem_assoc k l
  then ListLabels.map l ~f:(fun (k', v') -> if String.equal k k' then k, v else k', v')
  else (k, v) :: l
;;

let prefer_env conf =
  let f env key (fields, s3_fields) =
    let v = Sys.getenv_opt env in
    match v with
    | Some v -> upsert_assoc key v fields, s3_fields
    | None -> fields, s3_fields
  in
  ListLabels.fold_left
    ~init:conf
    ~f:(fun conf (env, key) -> f env key conf)
    (* TODO: auto generation (via botocore input json?) *)
    [ "AWS_ACCESS_KEY_ID", "aws_access_key_id"
    ; "AWS_DEFAULT_REGION", "region"
    ; "AWS_REGION", "region"
    ; "AWS_ROLE_ARN", "role_arn"
    ; "AWS_ROLE_SESSION_NAME", "role_session_name"
    ; "AWS_SECRET_ACCESS_KEY", "aws_secret_access_key"
    ; "AWS_SESSION_TOKEN", "aws_session_token"
    ]
;;

(** Read conf file and format as JSON. If [profile] is not found in a file, then returns empty JSON record [{}].
    @param profile The profile is [default] by default, or given by [AWS_PROFILE] environment variable.
 *)
let read_file ?profile filename =
  let profile = merge_profile profile in
  if Sys.file_exists filename
  then
    chunk_file filename
    |> Parse.parse
    |> List.assoc_opt profile
    |> Option.map (fun conf -> to_yojson @@ prefer_env @@ conf)
    |> Option.value ~default:(`Assoc [])
  else (
    let () =
      Logs.debug (fun m ->
          m
            ~header:"aws-config"
            "file %s not found: read only environment variables"
            filename)
    in
    to_yojson @@ prefer_env @@ ([], []))
;;

let get_home () =
  match Sys.getenv_opt "HOME" with
  | Some home -> home
  | None -> failwith "HOME environment variable not set"
;;

let read_aws_file ?profile basename default_env =
  let file =
    match Sys.getenv_opt default_env with
    | Some filename -> filename
    | None ->
      let home = get_home () in
      String.concat "/" [ home; ".aws"; basename ]
  in
  read_file ?profile file
;;

(** Read credentials file and select profile.
    The file to read is ~/.aws/credentials and/or given by [AWS_SHARED_CREDENTIALS_FILE] environment variable.
    @param profile The profile is [default] by default, or given by [AWS_PROFILE] environment variable.
    @raise Profile_not_found when the profile is not found.
 *)
let read_credentials ?profile () =
  read_aws_file ?profile "credentials" "AWS_SHARED_CREDENTIALS_FILE"
;;

(** Read config file.
    The file to read is ~/.aws/config and/or given by [AWS_CONFIG_FILE] environment variable.
    @param profile The profile is [default] by default, or given by [AWS_PROFILE] environment variable.
    @raise Profile_not_found when the profile is not found.
 *)
let read_config ?profile () = read_aws_file ?profile "config" "AWS_CONFIG_FILE"
