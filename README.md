http://marianoguerra.org/posts/basic-tcp-echo-server-with-rebar-reltool-ranch-and-lager.html

update to erlang/otp 20, rebar3

.. title: basic TCP echo server with rebar, reltool, ranch and lager
.. slug: basic-tcp-echo-server-with-rebar-reltool-ranch-and-lager
.. date: 2015-02-05 20:17:18 UTC
.. tags:
.. link:
.. description:
.. type: text

create project skeleton::

    # install Erlang/OTP 20
    wget https://s3.amazonaws.com/rebar3/rebar3
    chmod u+x rebar3
    ./rebar3 local install
    ===> Extracting rebar3 libs to ~/.cache/rebar3/lib...
    ===> Writing rebar3 run script ~/.cache/rebar3/bin/rebar3...
    ===> Add to $PATH for use: export PATH=$PATH:~/.cache/rebar3/bin
    # https://www.rebar3.org/docs/getting-started#section-extracting-and-upgrading
    rebar3 new release eco
    cd eco

let's add some dependencies, ranch to accept tcp connections and lager for logging,
for that open rebar.config with your text editor and enter this::


    {deps, [{lager, "3.6.7", {git, "https://github.com/erlang-lager/lager", {tag, "3.6.7"}}},
            {ranch, "1.6.2", {git, "https://github.com/ninenines/ranch", {tag, "1.6.2"}}}
           ]}.
    {erl_opts, [debug_info, {parse_transform, lager_transform}]}.

.. note::

    if you put lager dep after ranch you will get an error when compiling, that's sad

now let's try compiling it::

    rebar3 get-deps
    rebar3 compile

we can start our app from the shell, which won't be really useful, but why not::

    erl -pa _build/default/lib/*/ebin

and we run::

    1> application:start(eco).
    ok

now let's use ranch and lager for something, first we create a protocol implementation,
open a file called eco_protocol.erl and put the following content in it:

.. code:: erlang

    -module(eco_protocol).
    -behaviour(ranch_protocol).

    -export([start_link/4]).
    -export([init/4]).

    start_link(Ref, Socket, Transport, Opts) ->
        Pid = spawn_link(?MODULE, init, [Ref, Socket, Transport, Opts]),
        {ok, Pid}.

    init(Ref, Socket, Transport, _Opts = []) ->
        ok = ranch:accept_ack(Ref),
        loop(Socket, Transport).

    loop(Socket, Transport) ->
        case Transport:recv(Socket, 0, 5000) of
            {ok, Data} ->
                lager:info("echoing ~p", [Data]),
                Transport:send(Socket, Data),
                loop(Socket, Transport);
            _ ->
                ok = Transport:close(Socket)
        end.

edit the start function in src/eco_app.erl so it looks like this:

.. code:: erlang

    start(_StartType, _StartArgs) ->
        {ok, _} = ranch:start_listener(eco, 1, ranch_tcp, [{port, 1883}],
                                       eco_protocol, []),
        eco_sup:start_link().


and add the apps we need in eco.app.src by adding ranch and lager to the applications entry like this:

.. code:: erlang

    {applications, [kernel,
                    stdlib,
                    ranch,
                    lager
                   ]},

now let's compile and try again::

    rebar3 compile

::

    Erlang/OTP 20 [erts-9.2] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:10] [kernel-poll:false]

    Eshell V9.2  (abort with ^G)
    1> application:start(eco).
    {error,{not_started,ranch}}
    2> application:start(ranch).
    ok
    3> application:start(eco).
    {error,{not_started,lager}}
    4> application:start(lager).
    {error,{not_started,goldrush}}
    5> application:start(goldrush).
    {error,{not_started,syntax_tools}}
    6> application:start(syntax_tools).
    ok
    7> application:start(goldrush).
    {error,{not_started,compiler}}
    8> application:start(compiler).
    ok
    9> application:start(goldrush).
    ok
    10> application:start(lager).
    ok
    11> 21:05:52.373 [info] Application lager started on node nonode@nohost
    11> application:start(eco).
    ok
    21:06:09.335 [info] Application eco started on node nonode@nohost

.. note::

    user Cloven from reddit noted that instead of starting all the applications
    by hand in order you could use:

    application:ensure_all_started(eco).

    I was sure there was a way to do it since each app specified the
    dependencies, you can tell from the fact that each app tells you which one
    it needs before starting, but I didn't know which was the function to call.

    thanks to him!

now let's send some data::

    telnet localhost 1883

    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    asd
    asd

(I wrote the first asd, the second is the reply)

in the console you should see this log line::

    21:10:05.098 [info] echoing <<"asd\r\n">>

now let's try to build a release::

    rebar3 release

now let's start our server::

    ./_build/default/rel/eco/bin/eco console

you should see some output like this::

    Erlang/OTP 20 [erts-9.2] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:10] [kernel-poll:false]

    =INFO REPORT==== 5-Feb-2015::22:15:22 ===
    inet_parse:"/etc/resolv.conf":4: erroneous line, SKIPPED
    21:15:22.393 [info] Application lager started on node 'eco@127.0.0.1'
    21:15:22.394 [info] Application eco started on node 'eco@127.0.0.1'
    Eshell V9.2  (abort with ^G)
    (eco@127.0.0.1)1>

now let's telnet again::

    telnet localhost 1883

    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    lala!
    lala!

on the console again you should see some log like this::

    21:16:01.540 [info] echoing <<"lala!\r\n">>

and that's it, now evolve your echo server into an actual server :)
