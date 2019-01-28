%%%-------------------------------------------------------------------
%%% @author xueshumeng <xue.shumeng@yahoo.com>
%%% @copyright (C) 2018, xueshumeng
%%% @doc
%%%
%%% @end
%%% Created : 31 Dec 2018 by xueshumeng <xue.shumeng@yahoo.com>
%%%-------------------------------------------------------------------
-module('make-words').
-export([start/2]).

-define(api_url, "http://fanyi.youdao.com/openapi.do?keyfrom=YouDaoCV&key=659600698&type=data&doctype=json&version=1.1&q=~s").
-define(voice_url, "http://dict.youdao.com/dictvoice?type=2&audio=~p").

start(WordsFile, Output) ->
    case filelib:is_file(WordsFile) and (not filelib:is_dir(WordsFile)) of
	true ->
	    {ok, Io} = file:open(WordsFile, [read]),
	    Sum = process_line(Io, io:get_line(Io, ''), []),
	    inets:start(),
	    WordsMap = [translate_word(Word) || Word <- Sum],
	    {ok, Ioo} = file:open(Output, [write]),
	    [process_words_map(Map, Ioo) || Map <- WordsMap],

	    inets:stop();
	false ->
	    io:format("~p is not a file.", [WordsFile])
    end.

process_words_map(#{<<"basic">> := #{<<"explains">> := Explains, <<"phonetic">> := Phonetic, <<"uk-phonetic">> := UKPhonetic, <<"us-phonetic">> := USPhonetic}, <<"errorCode">> := 0, <<"query">> := Query}, Io) ->
    if Query =/= <<"">> -> io:format(Io, "~n~n~n~ts,", [Query]); true -> "" end,
    if Phonetic =/= <<"">> -> io:format(Io, "ST-PHONETIC: /~ts/~n", [binary_to_list(Phonetic)]); true -> "" end,
    if Phonetic =/= <<"">> -> io:format(Io, "US-PHONETIC: /~ts/~n", [binary_to_list(USPhonetic)]); true -> "" end,
    if Phonetic =/= <<"">> -> io:format(Io, "UK-PHONETIC: /~ts/~n", [binary_to_list(UKPhonetic)]); true -> "" end,

    lists:foldl(fun(Explain, _) -> io:format(Io, "~ts~n", [binary_to_list(Explain)]) end, "", Explains);

process_words_map(#{<<"basic">> := #{<<"explains">> := Explains}, <<"errorCode">> := 0, <<"query">> := Query}, Io) ->
    if Query =/= <<"">> -> io:format(Io, "~n~n~n~ts,", [Query]); true -> "" end,
    lists:foldl(fun(Explain, _) -> io:format(Io, "~n~ts", [binary_to_list(Explain)]) end, "", Explains);

process_words_map(#{<<"errorCode">> := ErrorCode}, _Io) -> io:format("Error Code: ~p~n", [ErrorCode]).

process_line(_Io, eof, Sum) -> Sum;
process_line(Io, Line, Sum) ->
    case re:run(Line, "^((?:\\w+\\s*)+)$", [{capture, [1], list}, ungreedy]) of
	{match, [Word]} ->
	    process_line(Io, io:get_line(Io, ''), [Word | Sum]);
	_ ->
	    process_line(Io, io:get_line(Io, ''), Sum)
    end.

translate_word(Word) ->
    RawURI = io_lib:format(?api_url, [http_uri:encode(Word)]),
    case httpc:request(RawURI) of
	{ok,{{_, 200, "OK"}, _Headers, Body}} ->
	    jsone:decode(list_to_binary(Body));
	_ ->
	    io:format("Request Error.~n")
    end.
