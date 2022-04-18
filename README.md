AWS-config
===

Read AWS configuration in OCaml.

```ocaml
let config = Aws_config.read_config () in
Aws_config.(config #. "aws_secret_access_key")
```
