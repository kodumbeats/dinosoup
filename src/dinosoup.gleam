//// Dinosoup is an attempt of all time to implement the :simple_one_for_one
//// gleam/erlang/supervisor restart strategy, inspired by elixir/dynamicsupervisor

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/function
import gleam/io
import gleam/list
import gleam/otp/actor

// types
pub type Child(state, msg) =
  #(Pid, Subject(msg), ChildSpec(state, msg))

pub type ChildSpec(state, msg) {
  ChildSpec(state: state, loop: fn(msg, state) -> actor.Next(msg, state))
}

pub type ChildStartError {
  StartError(actor.StartError)
  PidError(Dynamic)
}

pub type ExitMessage =
  process.ExitMessage

pub type ExitReason =
  process.ExitReason

pub type Message(state, msg) {
  Children(reply_with: Subject(List(Child(state, msg))))
  Exit(ExitMessage)
  KillChild(Pid, reply_with: Subject(Result(Nil, Nil)))
  StartChild(
    ChildSpec(state, msg),
    reply_with: Subject(Result(Subject(msg), StartError)),
  )
  Stop(ExitReason)
}

pub type StartError =
  actor.StartError

pub type State(state, msg) {
  State(children: List(Child(state, msg)))
}

pub type Supervisor(state, msg) =
  Subject(Message(state, msg))

// fns

pub fn start() -> Result(Supervisor(state, msg), StartError) {
  actor.Spec(init: init, init_timeout: 5000, loop: handler)
  |> actor.start_spec()
}

pub fn start_child(
  supervisor: Supervisor(state, msg),
  child_spec: ChildSpec(state, msg),
) {
  actor.call(supervisor, StartChild(child_spec, _), 3000)
}

pub fn kill_child(supervisor: Supervisor(state, msg), child: Pid) {
  actor.call(supervisor, KillChild(child, _), 3000)
}

pub fn stop(supervisor: Supervisor(state, msg)) {
  actor.send(supervisor, Stop(process.Normal))
}

pub fn children(supervisor: Supervisor(state, msg)) {
  actor.call(supervisor, Children, 3000)
}

fn init() {
  let subject = process.new_subject()

  let selector =
    process.new_selector()
    |> process.selecting(subject, function.identity)
    |> process.selecting_trapped_exits(Exit)

  let state = State(children: [])

  actor.Ready(state, selector)
}

fn handler(message: Message(state, msg), state: State(state, msg)) {
  case message {
    Children(client) -> {
      actor.send(client, state.children)
      actor.continue(state)
    }
    Exit(exit_message) -> handle_exit(exit_message.pid, state)
    KillChild(pid, client) -> {
      case
        state.children
        |> list.pop(fn(c) { c.0 == pid })
      {
        Ok(#(_, other_children)) -> {
          let assert Nil = process.kill(pid)

          actor.send(client, Ok(Nil))
          actor.continue(State(children: other_children))
        }
        Error(_) -> {
          actor.send(client, Error(Nil))
          actor.continue(state)
        }
      }
      actor.send(client, Ok(Nil))
      actor.continue(state)
    }
    StartChild(spec, client) -> {
      case start_child_spec(spec) {
        Ok(new_child) -> {
          actor.send(client, Ok(new_child.1))
          actor.continue(State(children: [new_child, ..state.children]))
        }
        Error(err) -> {
          actor.send(client, Error(err))
          actor.continue(state)
        }
      }
    }
    Stop(exit_reason) -> {
      actor.Stop(exit_reason)
    }
  }
}

fn start_child_spec(
  spec: ChildSpec(state, msg),
) -> Result(Child(state, msg), StartError) {
  // Our job now to handle these exit messages
  process.trap_exits(True)

  case actor.start(spec.state, spec.loop) {
    Ok(new_child) -> {
      #(process.subject_owner(new_child), new_child, spec)
      |> Ok()
    }
    Error(start_error) -> Error(start_error)
  }
}

fn handle_exit(
  pid: Pid,
  state: State(state, msg),
) -> actor.Next(Message(state, msg), State(state, msg)) {
  case
    state.children
    |> list.pop(fn(c) { c.0 == pid })
  {
    Ok(#(child, other_children)) -> {
      // Restart with initial spec
      case start_child_spec(child.2) {
        Ok(new_child) -> {
          actor.continue(State(children: [new_child, ..other_children]))
        }
        Error(_) -> {
          actor.Stop(process.Abnormal("turn-it-off-and-back-on-again failed!"))
        }
      }
    }
    Error(_) -> {
      // TODO Not sure how this case happens during tests.
      actor.continue(state)
    }
  }
}
