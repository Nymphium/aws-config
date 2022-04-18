AWS-config
===

Read AWS configuration as Yojson format.

```ocaml
(* Read ~/.aws/config *)
let config = Aws_config.read_config () in
Aws_config.(config #. "aws_secret_access_key");;
- : string option = Some "-secret access key-"

(* Respect several AWS environment variables:
   suppose `AWS_SECRET_ACCESS_KEY` = `foobar`, then *)
let config = Aws_config.read_config () in
Aws_config.(config #. "aws_secret_access_key");;
- : string option = Some "foobar"

(* Profile selection:
   suppose "region = some-city" in "my_conf", "./config", then *)
let config = Aws_config.read_file ~profile:"my_conf" "config" () in
Aws_config.(config #. "region");;
- : string option = Some "some-city" 
```

## Related
[ocaml-aws](https://github.com/inhabitedtype/ocaml-aws) ... OCaml bindings for AWS
