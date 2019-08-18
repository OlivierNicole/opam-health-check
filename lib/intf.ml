open Lwt.Infix

module State = struct
  type t = Good | Partial | Bad | NotAvailable | InternalFailure

  let equal x y = match x, y with
    | Good, Good | Partial, Partial | Bad, Bad | NotAvailable, NotAvailable | InternalFailure, InternalFailure -> true
    | Good, _ | Partial, _ | Bad, _ | NotAvailable, _ | InternalFailure, _ -> false

  let from_string = function
    | "good" -> Good
    | "partial" -> Partial
    | "bad" -> Bad
    | "not-available" -> NotAvailable
    | "internal-failure" -> InternalFailure
    | _ -> failwith "not a state"

  let to_string = function
    | Good -> "good"
    | Partial -> "partial"
    | Bad -> "bad"
    | NotAvailable -> "not-available"
    | InternalFailure -> "internal-failure"
end

module Compiler = struct
  type t = Comp of string

  let from_string x =
    if not (Oca_lib.is_valid_filename x) then
      failwith "Forbidden switch name";
    Comp x

  let to_string (Comp x) = x
  let equal (Comp x) (Comp y) = OpamVersionCompare.equal x y
  let compare (Comp x) (Comp y) = OpamVersionCompare.compare x y
end

module Switch = struct
  type t = Switch of Compiler.t * string

  let create ~name ~switch = Switch (Compiler.from_string name, switch)

  let name (Switch (x, _)) = x
  let switch (Switch (_, x)) = x

  let equal (Switch (x, _)) (Switch (y, _)) = Compiler.equal x y
  let compare (Switch (x, _)) (Switch (y, _)) = Compiler.compare x y
end

module Log = struct
  type t =
    | Compressed of bytes Lwt.t
    | Unstored of (unit -> string Lwt.t)

  let compressed_buffer_len = ref 0

  let compressed s =
    let s =
      s >|= fun s ->
      compressed_buffer_len := max !compressed_buffer_len (String.length s);
      LZ4.Bytes.compress (Bytes.unsafe_of_string s)
    in
    Compressed s
  let unstored f = Unstored f

  let to_string = function
    | Compressed s -> s >|= fun s -> Bytes.unsafe_to_string (LZ4.Bytes.decompress ~length:!compressed_buffer_len s)
    | Unstored f -> f ()
end

module Instance = struct
  type t = {
    compiler : Compiler.t;
    state : State.t;
    content : Log.t;
  }

  let create compiler state content = {compiler; state; content}

  let compiler x = x.compiler
  let state x = x.state
  let content x = Log.to_string x.content
end

module Pkg = struct
  type t = {
    full_name : string;
    name : string;
    version : string;
    maintainers : string list;
    instances : Instance.t list;
    revdeps : int;
  }

  let create ~full_name ~instances ~maintainers ~revdeps =
    let (name, version) =
      match String.Split.left ~by:"." full_name with
      | Some x -> x
      | None -> failwith "packages must have a version separated by a dot"
    in
    {full_name; name; version; maintainers; instances; revdeps}

  let equal x y = OpamVersionCompare.equal x.full_name y.full_name
  let compare x y = OpamVersionCompare.compare x.full_name y.full_name

  let full_name x = x.full_name
  let name x = x.name
  let version x = x.version
  let maintainers x = x.maintainers
  let instances x = x.instances
  let revdeps x = x.revdeps
end

module Pkg_diff = struct
  type diff =
    | NowInstallable of State.t
    | NotAvailableAnymore of State.t
    | StatusChanged of (State.t * State.t)

  type t = {
    full_name : string;
    comp : Compiler.t;
    diff : diff;
  }
end
