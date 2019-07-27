open Core
open Opcode

exception Fault of string

type pc = int
and st = value Stack.t
and registers = (int, value) Hashtbl.t
and value =
  | Int of int
  | State of pc * (int, value) Hashtbl.t

let rec show_value (v: value) =
  match v with
  | Int i -> sprintf "Int %d" i 
  | State (pc, reg) -> sprintf "State %d, <registers>" pc

let _debug = ref false
let printd msg = if !_debug then printf "%s\n" msg else ()

type program = opcode array

let pc: pc ref = ref 0

let labels: (string, int) Hashtbl.t = Hashtbl.create (module String)
let addl (name: string) (pc: int) = Hashtbl.set ~key:name ~data:pc labels
let getl (name: string) =
  match Hashtbl.find labels name with
  | Some pc -> pc
  | None -> raise (Fault (sprintf "Label not defined: %s" name))
let show_labels () =
  let l = Hashtbl.to_alist labels in
  sprintf "Labels:";
  List.iter l ~f:(fun (label, pc) -> printd (sprintf "%s: %d" label pc))

let stack: st ref = ref (Stack.create ())

let push (v: value) = Stack.push !stack v 
let pop (): value =
  match Stack.pop !stack with
  | Some v -> v
  | None -> raise (Fault "pop from empty stack")
let show_stack () =
  let l = Stack.to_list !stack in
  printd "Stack:";
  List.iter l ~f:(fun v -> printd (sprintf "%s" (show_value v)))

let reg: registers ref = ref (Hashtbl.create (module Int))

let set (rid: int) (v: value) = Hashtbl.set ~key:rid ~data:v !reg
let get (rid: int) =
  match Hashtbl.find !reg rid with
  | Some v -> v
  | None -> raise (Fault "get from uninitialized register")
let show_registers () =
  let l = Hashtbl.to_alist !reg in
  printd "Registers:\n";
  List.iter l ~f:(fun (rid, v) -> printd (sprintf "$%d: %s" rid (show_value v)))

let eval (op: opcode) =
  printd (sprintf "Evaluating: %s" (show_opcode op));
  match op with
  | Pushi i -> (
    printd (sprintf "Pushing %d" i);
    push (Int i);
    incr pc
  )
  | Pushr r -> (
    printd (sprintf "Pushing value from $%d" r);
    let v = get r in
    printd (sprintf "Pushing value: %s" (show_value v));
    push v;
    incr pc
  )
  | Pop r -> (
    printd (sprintf "Popping value into $%d" r);
    let v = pop () in
    printd (sprintf "Storing value %s into $%d" (show_value v) r);
    set r v;
    incr pc
  )
  | Call name -> (
    printd (sprintf "Calling %s" name);
    match name with
    | "vm_print_int" -> (
      printd (sprintf "Calling builtin vm_print_int");
      let v = pop () in
      match v with
      | Int i -> printf "%d" i; incr pc
      | _ -> raise (Fault (sprintf "vm_print_int on a non-int value %s" (show_value v)))
    )
    | _ -> (
      let st = State (!pc + 1, !reg) in
      push st;
      printd (sprintf "Pushing state %s onto stack" (show_value st));
      let pc' = getl name in
      printd (sprintf "New PC: %d" pc');
      pc := pc'
    )
  )
  | Ret -> (
    printd "Returning from a function call";
    let v = pop () in
    match v with
    | State (pc', reg') -> (
      pc := pc';
      reg := reg';
      printd (sprintf "New PC: %d" !pc)
    )
    | _ -> raise (Fault (sprintf "ret on non-state value: %s" (show_value v)))
  )
  | Addi -> (
    let a = pop () in
    let b = pop () in
    match a, b with
    | Int a, Int b -> (
      printd (sprintf "Adding %d and %d" a b);
      push (Int (a + b));
      incr pc
    )
    | _, _ -> raise (Fault (sprintf "addi on non-int values %s, %s" (show_value a) (show_value b)))
  )
  | Divi -> (
    let a = pop () in
    let b = pop () in
    match a, b with
    | Int a, Int b -> (
      printd (sprintf "Adding %d and %d" a b);
      push (Int (a / b));
      incr pc
    )
    | _, _ -> raise (Fault (sprintf "divi on non-int values %s, %s" (show_value a) (show_value b)))
  )

let run (p: program) ?debug:(debug=false) =
  _debug := debug;
  push (State (9999999, !reg)); (* Return from main *)
  let pend = Array.length p in
  while !pc < pend do
    eval (Array.get p !pc);
    show_stack ();
    show_registers ();
    printd (sprintf "Next PC: %d\n" !pc)
  done