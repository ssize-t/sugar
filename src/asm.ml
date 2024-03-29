open Core

type instr =
  | Label of string

  | Pushnil
  | Pushi of int
  | Pushr of int
  | Popr of int
  | Pop

  | Syscall of string
  | Call of string
  | Ret
  | Jc of string
  | Jmp of string
  | Halt

  | Cons
  | Hdl

  | Addi
  | Divi
  [@@deriving show]

exception Parse_error of string

let show_instr (op: instr): string =
  match op with
  | Label name -> sprintf "%s:" name
  | Pushi x -> sprintf "\tpushi %d" x
  | Pushr rid -> sprintf "\tpushr $%d" rid
  | Popr rid -> sprintf "\tpopr $%d" rid
  | Syscall name -> sprintf "\tsyscall %s" name
  | Call name -> sprintf "\tcall %s" name
  | Ret -> "\tret"
  | Addi -> "\taddi"
  | Divi -> "\tdivi"
  | Hdl -> "\thdl"
  | Jc name -> sprintf "\tjc %s" name
  | Pushnil -> "\tpushnil"
  | Cons -> "\tcons"
  | Jmp name -> sprintf "\tjmp %s" name
  | Halt -> "\thalt"
  | Pop -> "\tpop"

type program = instr list

let show_prog (p: program): string =
  p |> List.map ~f:show_instr |> String.concat ~sep:"\n"

let instr_of_string (s: string): instr =
  match%pcre s with
  | {|(?<label>.[^:]+):|} -> Label label
  | {|[\t](?<instr>[a-z]*) (?<arg>.+)|} -> (
    match instr with
    | "pushi" -> Pushi (Int.of_string arg)
    | "pushr" -> Pushr (Int.of_string (String.slice arg 1 (String.length arg)))
    | "popr" -> Popr (Int.of_string (String.slice arg 1 (String.length arg)))
    | "syscall" -> Syscall arg
    | "call" -> Call arg
    | "jc" -> Jc arg
    | "jmp" -> Jmp arg
    | _ -> raise (Parse_error (sprintf "Unknown instruction: %s" instr))
  )
  | {|[\t](?<instr>[a-z]*)|} -> (
    match instr with
    | "ret" -> Ret
    | "addi" -> Addi
    | "divi" -> Divi
    | "hdl" -> Hdl
    | "pushnil" -> Pushnil
    | "cons" -> Cons
    | "halt" -> Halt
    | "pop" -> Pop
    | _ -> raise (Parse_error (sprintf "Unknown instruction: %s" instr))
  )
  | _ -> raise (Parse_error (sprintf "Unrecognized token: %s" s))

let prog_of_string (s: string): program =
  s
  |> String.split_lines
  |> List.filter ~f:(fun s -> not (String.is_prefix (String.strip s) ~prefix:"#"))
  |> List.filter ~f:(fun s -> String.length (String.strip s) > 0)
  |> List.map ~f:instr_of_string

let to_file (p: program) (filename: string) =
  p |> show_prog |> Out_channel.write_all filename

let from_file (filename: string): program =
  In_channel.read_all filename |> prog_of_string

let%test "asm_string_roundtrip" =
  let prog = [
    Label "main";
    Pushi 1;
    Pushr 2;
    Popr 3;
    Syscall "print_int";
    Call "main";
    Jc "main";
    Jmp "main";
    Pushnil;
    Halt;
    Hdl;
    Cons;
    Ret;
    Addi;
    Pop;
    Divi
  ] in
  let prog_s = show_prog prog in
  let prog' = prog_of_string prog_s in
  match List.zip prog prog' with
  | None -> false
  | Some l -> List.fold l ~init:true ~f:(fun acc (i, i') -> if i = i' then () else printf "%s != %s\n" (show_instr i) (show_instr i'); acc && (i = i'))

let%test "asm_file_roundtrip" =
  let prog = [
    Label "main";
    Pushi 1;
    Pushr 2;
    Popr 3;
    Syscall "print_int";
    Call "main";
    Jc "main";
    Jmp "main";
    Pushnil;
    Halt;
    Hdl;
    Cons;
    Ret;
    Addi;
    Pop;
    Divi
  ] in
  to_file prog "tmp.sugar";
  let prog' = from_file "tmp.sugar" in
  (* Sys.remove "tmp.sugar"; *)
  match List.zip prog prog' with
  | None -> false
  | Some l -> List.fold l ~init:true ~f:(fun acc (i, i') -> if i = i' then () else printf "%s != %s\n" (show_instr i) (show_instr i'); acc && (i = i'))