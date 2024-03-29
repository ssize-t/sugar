open Core

exception Compile_error of string

let syscall_id = function
  | "print_int" -> 0
  | s -> raise (Compile_error (sprintf "Unknown syscall: %s" s))

let compile (prog: Asm.program): Opcode.program =
  let prog': Opcode.opcode array = Array.create ~len:(List.length prog) Opcode.Ret in
  let pc = ref 0 in
  let symtab: (string, int) Hashtbl.t = Hashtbl.create (module String) in
  (* forward-declarations *)
  List.iteri prog ~f:(fun i instr -> (
    match instr with
    | Asm.Label label -> Hashtbl.set symtab ~key:label ~data:!pc
    | _ -> incr pc;
  ));
  pc := 0;
  List.iteri prog ~f:(fun i instr -> (
    match instr with
    | Asm.Label label -> ()
    | Asm.Pushi i -> Array.set prog' !pc (Opcode.Pushi i); incr pc
    | Asm.Pushr rid -> Array.set prog' !pc (Opcode.Pushr rid); incr pc
    | Asm.Popr rid -> Array.set prog' !pc (Opcode.Popr rid); incr pc
    | Asm.Syscall name -> Array.set prog' !pc (Opcode.Syscall (syscall_id name)); incr pc 
    | Asm.Call label -> (
      match Hashtbl.find symtab label with
      | None -> raise (Compile_error (sprintf "undefined label: %s" label))
      | Some pc' -> Array.set prog' !pc (Opcode.Call pc'); incr pc
    )
    | Asm.Jc label -> (
      match Hashtbl.find symtab label with
      | None -> raise (Compile_error (sprintf "undefined label: %s" label))
      | Some pc' -> Array.set prog' !pc (Opcode.Jc pc'); incr pc
    )
    | Asm.Jmp label -> (
      match Hashtbl.find symtab label with
      | None -> raise (Compile_error (sprintf "undefined label: %s" label))
      | Some pc' -> Array.set prog' !pc (Opcode.Jmp pc'); incr pc
    )
    | Asm.Ret -> Array.set prog' !pc Opcode.Ret; incr pc
    | Asm.Addi -> Array.set prog' !pc Opcode.Addi; incr pc
    | Asm.Divi -> Array.set prog' !pc Opcode.Divi; incr pc
    | Asm.Hdl -> Array.set prog' !pc Opcode.Hdl; incr pc
    | Asm.Pushnil -> Array.set prog' !pc Opcode.Pushnil; incr pc
    | Asm.Cons -> Array.set prog' !pc Opcode.Cons; incr pc
    | Asm.Halt -> Array.set prog' !pc Opcode.Halt; incr pc
    | Asm.Pop -> Array.set prog' !pc Opcode.Pop; incr pc
  ));
  Array.slice prog' 0 !pc

let%test "test_compile" =
  let open Asm in
  let prog = [
    Label "main";
    Pushi 3;
    Pushi 1;
    Call "mean";
    Syscall "print_int";
    Hdl;
    Ret;
    Label "mean";
    Jc "mean";
    Jmp "mean";
    Halt;
    Popr 1;
    Addi;
    Addi;
    Popr 2;
    Pushnil;
    Cons;
    Pushi 3;
    Pushr 2;
    Divi;
    Pushr 1;
    Pop;
    Ret
  ] in
  let open Opcode in
  let prog' = [|
    Pushi 3;
    Pushi 1;
    Call 6;
    Syscall 0;
    Hdl;
    Ret;
    Jc 6;
    Jmp 6;
    Halt;
    Popr 1;
    Addi;
    Addi;
    Popr 2;
    Pushnil;
    Cons;
    Pushi 3;
    Pushr 2;
    Divi;
    Pushr 1;
    Pop;
    Ret
  |] in
  let prog'' = compile prog in
  if prog' = prog'' then true else (
  printf "%s\n\n" (show_program prog');
  printf "%s\n" (show_program prog''); false)