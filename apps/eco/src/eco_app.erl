%%%-------------------------------------------------------------------
%% @doc eco public API
%% @end
%%%-------------------------------------------------------------------

-module(eco_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    {ok, _} = ranch:start_listener(eco, 1, ranch_tcp, [{port, 1883}],
                                   eco_protocol, []),
    eco_sup:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
