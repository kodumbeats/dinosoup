// imports

import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleeunit
import gleeunit/should
import dinosoup.{ChildSpec}

pub fn main() {
  gleeunit.main()
}

// tests

pub fn start_stop_test() {
  let sup =
    dinosoup.start()
    |> should.be_ok()

  sup
  |> dinosoup.children()
  |> list.length()
  |> should.equal(0)

  sup
  |> dinosoup.stop()
  |> should.equal(Nil)
}

pub fn start_child_test() {
  let assert Ok(sup) = dinosoup.start()

  sup
  |> dinosoup.start_child(ChildSpec(["test1"], test_handler))
  |> should.be_ok()

  sup
  |> dinosoup.children()
  |> list.length()
  |> should.equal(1)

  sup
  |> dinosoup.start_child(ChildSpec(["test2"], test_handler))
  |> should.be_ok()

  sup
  |> dinosoup.children()
  |> list.length()
  |> should.equal(2)
}

pub fn restart_child_on_exit_test() {
  let assert Ok(sup) = dinosoup.start()

  let assert Ok(test1) =
    sup
    |> dinosoup.start_child(ChildSpec(["test1"], test_handler))

  let assert [#(old_pid, _, _)] =
    sup
    |> dinosoup.children()

  test1
  |> rip()

  let assert [#(new_pid, test2, _)] =
    sup
    |> dinosoup.children()

  // if the pid is new
  { new_pid == old_pid }
  |> should.be_false()

  // then the server should be too
  test2
  |> actor.call(Ping("pong", _), 10)
  |> should.equal("pong")
}

// TODO figure out a way to keep children dead
//
// pub fn kill_child_test() {
//   let assert Ok(sup) = dinosoup.start()
//
//   sup
//   |> dinosoup.start_child(ChildSpec(["test1"], test_handler))
//   |> should.be_ok()
//
//   let assert [#(pid, _, _)] =
//     sup
//     |> dinosoup.children()
//
//   sup
//   |> dinosoup.kill_child(pid)
//   |> should.be_ok()
//
//   sup
//   |> dinosoup.children()
//   |> list.length()
//   |> should.equal(0)
// }

// mocks

pub type TestMessage {
  Ping(String, reply_with: process.Subject(String))
  RIP
}

pub type TestState =
  List(String)

fn rip(server: process.Subject(TestMessage)) {
  actor.send(server, RIP)
  process.sleep(1)
}

fn test_handler(msg: TestMessage, state: TestState) {
  case msg {
    Ping(pong, client) -> {
      actor.send(client, pong)
      actor.continue(state)
    }
    RIP -> actor.Stop(process.Abnormal("RIP"))
  }
}
