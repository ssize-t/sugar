open Core
open Opcode

exception Fault of string

type pc = int
and st = value Stack.t
and registers = (int, value) Hashtbl.t
and cond = bool
and base = state Stack.t
and state = pc * cond * registers
and value =
  | Int of int
  | Cons of value * value
  | Nil

let rec show_value (v: value) =
  match v with
  | Int i -> sprintf "Int %d" i
  | Cons (v, v') -> sprintf "Cons (%s, %s)" (show_value v) (show_value v')
  | Nil -> "Nil"

let show_state (s: state) =
  match s with
  | (pc, cond, base) -> sprintf "State (%d, %s, <registers>)" pc (if cond then "true" else "false")

let _debug = ref false
let printd msg = if !_debug then printf "%s\n" msg else ()

let cond: cond ref = ref false

let set_cond () = cond := true
let unset_cond () = cond := false

let pc: pc ref = ref 0

let stack: st ref = ref (Stack.create ())

let push (v: value) = Stack.push !stack v 
let pop (): value =
  match Stack.pop !stack with
  | Some v -> v
  | None -> raise (Fault "pop from empty stack")
let peek (): value =
  match Stack.top !stack with
  | Some v -> v
  | None -> raise (Fault "peek from empty stack")
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

let base: base = Stack.create ()

let push_base () =
  Stack.push base (!pc + 1, !cond, !reg)
let pop_base () =
  match Stack.pop base with
  | Some b -> b
  | None -> (
    printd "Return without a base pointer, assuming halt";
    (9999999, !cond, !reg)
  )

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
  | Popr r -> (
    printd (sprintf "Popping value into $%d" r);
    let v = pop () in
    printd (sprintf "Storing value %s into $%d" (show_value v) r);
    set r v;
    incr pc
  )
  | Syscall id -> (
    printd (sprintf "Executing syscall %d" id);
    match id with
    | 0 -> (
      printd "Executing print_int";
      let v = peek () in
      match v with
      | Int i -> printf "%d" i; incr pc
      | _ -> raise (Fault (sprintf "invalid argument for print_int: %s" (show_value v)))
    )
    | _ -> raise (Fault (sprintf "Unknown syscall: %d" id))
  )
  | Call pc' -> (
    printd (sprintf "Calling funcion at %d" pc');
    push_base ();
    pc := pc'
  )
  | Ret -> (
    printd "Returning from a function call";
    let (pc', cond', reg') = pop_base () in
    pc := pc';
    reg := reg';
    cond := cond';
    printd (sprintf "New PC: %d" !pc);
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
  | Hdl -> (
    let l = pop () in
    match l with
    | Cons (v, v') -> (
      printd (sprintf "Placing value %s at the top of the stack" (show_value v));
      push v';
      push v;
      incr pc
    )
    | Nil -> (
      printd "Pop on empty list, setting cond flag";
      set_cond ();
      incr pc;
    )
    | _ -> raise (Fault (sprintf "hdl on non-list value %s" (show_value l)))
  )
  | Jc pc' -> (
    match !cond with
    | false -> printd "Condition bit not set, resuming"; incr pc
    | true -> (
      printd (sprintf "Condition bit set, jumping to %d" pc');
      pc := pc';
      printd "Clearing condition bit";
      unset_cond ();
    )
  )
  | Pushnil -> (
    push Nil;
    incr pc;
  )
  | Cons -> (
    let a = pop () in
    let b = pop () in
    let c = Cons (a, b) in
    printd (sprintf "Pushing %s onto stack" (show_value c));
    push c;
    incr pc;
  )
  | Jmp pc' -> (
    printd (sprintf "Jumping to pc: %d" pc');
    pc := pc';
  )
  | Halt -> (
    printd "Halting execution";
    pc := 99999999;
  )
  | Pop -> (
    printd "Discarding top value from the stack";
    let _ = pop () in
    incr pc;
  )

let run (p: program) ?debug:(debug=false) =
  _debug := debug;
  let pend = Array.length p in
  while !pc < pend do
    eval (Array.get p !pc);
    show_stack ();
    show_registers ();
    printd (sprintf "Next PC: %d\n" !pc)
  done