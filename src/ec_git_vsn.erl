%%% vi:ts=4 sw=4 et
%%%-------------------------------------------------------------------
%%% @author Eric Merritt <ericbmerritt@gmail.com>
%%% @copyright 2011 Erlware, LLC.
%%% @doc
%%%  This provides an implementation of the ec_vsn for git. That is
%%%  it is capable of returning a semver for a git repository
%%% see ec_vsn
%%% see ec_semver
%%% @end
%%%-------------------------------------------------------------------
-module(ec_git_vsn).

-behaviour(ec_vsn).

%% API
-export([new/0,
         vsn/1]).

-export_type([t/0]).

%%%===================================================================
%%% Types
%%%===================================================================
%% This should be opaque, but that kills dialyzer so for now we export it
%% however you should not rely on the internal representation here
-type t() :: list().

%%%===================================================================
%%% API
%%%===================================================================

-spec new() -> t().
new() ->
    "*".

-spec vsn(t()) -> {ok, binary()} | {error, Reason::any()}.
vsn([]) ->
    vsn("*");
vsn(Glob) ->
    Result = do_cmd("git describe --tags --always --match '" ++ Glob ++ "'"),
    case re:split(Result, "-") of
        [Vsn, Count, RefTag] ->
            erlang:iolist_to_binary([strip_leading_v(Vsn),
                                     <<"+build.">>,
                                     Count,
                                     <<".ref.">>,
                                     RefTag]);
        [VsnOrRefTag] ->
            case re:run(VsnOrRefTag, "^[0-9a-fA-F]+$") of
                {match, _} ->
                    find_vsn_from_start_of_branch(VsnOrRefTag);
                nomatch ->
                    strip_leading_v(VsnOrRefTag)
            end;
        _ ->
            {error, {invalid_result, Result}}
    end.

%%%===================================================================
%%% Internal Functions
%%%===================================================================
-spec strip_leading_v(io_lib:chars()) -> string().
strip_leading_v(Vsn) ->
    case re:run(Vsn, "v?(.+)", [{capture, [1], binary}]) of
        {match, [NVsn]} ->
            NVsn;
        _ ->
            iolist_to_binary(Vsn)
    end.

-spec find_vsn_from_start_of_branch(string()) -> io_lib:chars().
find_vsn_from_start_of_branch(RefTag) ->
    Count = do_cmd("git rev-list HEAD --count"),
    erlang:iolist_to_binary(["0.0.0+build.", Count, ".ref.", RefTag]).

do_cmd(Cmd) ->
    trim_whitespace(os:cmd(Cmd)).

trim_whitespace(Input) ->
     re:replace(Input, "\\s+", "", [global]).
