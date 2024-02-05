# kodumbeats/dinosoup

[![Package Version](https://img.shields.io/hexpm/v/dinosoup)](https://hex.pm/packages/dinosoup)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/dinosoup/)

A Elixir/DynamicSupervisor / :simple_one_for_one strategy for gleam/{erlang,otp}.

> WORK IN PROGRESS - Use at your own risk pre v0.1.0 release on `hex`.

## Usage

Add the library to your Gleam project:

```sh
gleam add dinosoup
```

Then, in your code:

```gleam
import dinosoup
import some.{message_handler}

pub fn main() {
  let assert Ok(sup) = dinosoup.start()

  // children must implement same behavior (e.g. use the same handler)
  sup |> dinosoup.start_child(ChildSpec(["state"], message_handler))
  sup |> dinosoup.start_child(ChildSpec(["different_state"], message_handler))

  // to get at it later
  let [#(pid, actor, spec), .._rest] = sup |> dinosoup.children()

  // killed children stay dead, but Normal and Abnormal(reason)
  // exits will be restarted
  let assert Ok(Nil) = sup |> dinosoup.kill_child(pid)

  // and now only one remains
  let assert [_] = sup |> dinosoup.children()
}
```

Further documentation can be found at <https://hexdocs.pm/dinosoup>.

## Development

```sh
gleam format # Format the code
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

### TODO

- [x] Get `dinosoup.kill_child/2` working
- [ ] Implement more sophisticated restart/timeout strategies
- [ ] Harmonize more closely with `gleam/otp/supervisor` behavior

> made with <3 by kodumbeats
