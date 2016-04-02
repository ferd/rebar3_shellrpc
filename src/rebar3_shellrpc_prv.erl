-module(rebar3_shellrpc_prv).

-export([init/1, do/1, format_error/1]).

-define(PROVIDER, rebar3_shellrpc).
-define(DEPS, []).

%% ===================================================================
%% Public API
%% ===================================================================
-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    State1 = rebar_state:add_provider(
            State,
            providers:create([
                {name, ?PROVIDER},
                {module, ?MODULE},
                {bare, false},
                {deps, ?DEPS},
                {example, "rebar3 shellrpc <command>"},
                {short_desc, "Call running shell agent."},
                {desc, info()},
                {opts, [{name, undefined, "name", atom,
                         "Gives a long name to the node."},
                        {sname, undefined, "sname", atom,
                         "Gives a short name to the node."},
                        {setcookie, undefined, "setcookie", atom,
                         "Sets the cookie if the node is distributed."}]}
            ])
    ),
    {ok, State1}.



-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
    {Long, Short, DistOpts} = rebar_dist_utils:find_options(State),
    rebar_api:debug("Dist res: ~p", [{Long, Short, DistOpts}]),
    case type(Long, Short) of
        nodist ->
            ok;
        {Type, MaybeFull} ->
            rebar_dist_utils:Type(random_name(MaybeFull), DistOpts),
            case node() of
                'nonode@nohost' ->
                    ok;
                Name ->
                    TargetNode = expand(MaybeFull, Name),
                    case connect_remote(TargetNode) of
                        true ->
                            rebar_api:debug("Connected to ~p", [TargetNode]),
                            send_command(State, TargetNode);
                        false ->
                            rebar_api:debug("Failed to connect to ~p", [TargetNode]),
                            ok
                    end
            end
    end,
    {ok, State}.

-spec format_error(any()) ->  iolist().
format_error(Reason) ->
    io_lib:format("~p", [Reason]).
%% ===================================================================
%% Private
%% ===================================================================

info() ->
    "Call the rebar3 agent of a running node.\n".

type(undefined, undefined) ->
    nodist;
type(undefined, Name) ->
    {short, Name};
type(Name, undefined) ->
    {long, Name};
type(_, _) ->
    nodist.

random_name(MaybeFull) ->
    Rand = integer_to_list(erlang:phash2(os:timestamp())),
    case re:split(atom_to_list(MaybeFull), "@", [{return, list}]) of
        [_] -> % no trailing bit
            list_to_atom("shellrpc-"++Rand);
        [_, Host] ->
            list_to_atom("shellrpc-"++Rand++"@"++Host)
    end.

expand(MaybeFull, Local) ->
    MaybeFullStr = atom_to_list(MaybeFull),
    case re:split(MaybeFullStr, "@") of
        [_] -> % no trailing bit
            [_, Host] = re:split(atom_to_list(Local), "@", [{return, list}]),
            list_to_atom(MaybeFullStr ++ "@" ++ Host);
        [_, _] ->
            MaybeFull
    end.

connect_remote(Node) -> net_kernel:connect_node(Node).

send_command(State, Node) ->
    case strip_flags(rebar_state:command_args(State)) of
        [Command] ->
            rebar_api:debug("Sending command ~s to ~p~n", [Command, Node]),
            rpc:call(Node, r3, do, [list_to_atom(Command)]);
        [NameSpace, Command] ->
            rebar_api:debug("Sending command ~s in namespace ~s to ~p~n", [Command, NameSpace, Node]),
            rpc:call(Node, r3, do, [list_to_atom(NameSpace), list_to_atom(Command)])
    end.

strip_flags([]) ->
    [];
strip_flags([Flag = "--"++_ | Opts]) ->
    %% We always strip the flag. `--flag=Val' is covered in a single entry,
    %% but `--flag Val' requires two
    case re:split(Flag, "=") of
        [_] -> strip_flags(tl(Opts));
        [_,_] -> strip_flags(Opts)
    end;
strip_flags([Opt | Opts]) ->
    [Opt | strip_flags(Opts)].

