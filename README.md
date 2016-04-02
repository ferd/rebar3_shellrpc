rebar3_shellrpc
=====

A rebar plugin

Build
-----

    $ rebar3 compile

Use
---

Add the plugin to your rebar config, possibly the global one in
`~/.config/rebar3/rebar.config` :

```erlang
{plugins, [
    {rebar3_shellrpc, ".*", {git, "https://github.com/ferd/rebar3_shellrpc.git", {branch, "master"}}}
]}.
```

Use the `dist_node` option of rebar 3.1:

```erlang
{dist_node, [{sname, myproject}]}.
```

Boot a shell in a tab:

```
$ rebar3 shell
...
```

Then just call your plugin directly in the project

```
$ rebar3 shellrpc <cmd>
```

And <cmd> will be sent to the shell that is currently running. For example:

```
$ rebar3 shellrpc compile
```

Will recompile and reload code.

Vim Bindings
------------

```vim
autocmd FileType erlang map <F5> :! rebar3 shellrpc compile<cr>
autocmd FileType erlang map <F6> :! rebar3 shellrpc ct<cr>
autocmd FileType erlang map <F7> :! rebar3 shellrpc dialyzer<cr>
```
