-module(mp3_sync).
-export([find_sync/2]).

mapbitratedata() -> 
	[{{0,ver,layone},free},{{1,ver,layone},32},{{2,ver,layone},64},{{3,ver,layone},96},{{4,ver,layone},128},{{5,ver,layone},160},{{6,ver,layone},192},{{7,ver,layone},224},{{8,ver,layone},256},{{9,ver,layone},288},{{10,ver,layone},320},{{11,ver,layone},352},{{12,ver,layone},384},{{13,ver,layone},416},{{14,ver,layone},448},{{15,ver,layone},bad},
{{0,ver,laytwo},free},{{1,ver,laytwo},32},{{2,ver,laytwo},48},{{3,ver,laytwo},56},{{4,ver,laytwo},64},{{5,ver,laytwo},80},{{6,ver,laytwo},96},{{7,ver,laytwo},112},{{8,ver,laytwo},128},{{9,ver,laytwo},160},{{10,ver,laytwo},192},{{11,ver,laytwo},224},{{12,ver,laytwo},256},{{13,ver,laytwo},320},{{14,ver,laytwo},384},{{15,ver,laytwo},bad},
{{0,ver,laythr},free},{{1,ver,laythr},32},{{2,ver,laythr},40},{{3,ver,laythr},48},{{4,ver,laythr},56},{{5,ver,laythr},64},{{6,ver,laythr},80},{{7,ver,laythr},96},{{8,ver,laythr},112},{{9,ver,laythr},128},{{10,ver,laythr},160},{{11,ver,laythr},192},{{12,ver,laythr},224},{{13,ver,laythr},256},{{14,ver,laythr},320},{{15,ver,laythr},bad},
{{0,vertwo,layone},free},{{1,vertwo,layone},32},{{2,vertwo,layone},64},{{3,vertwo,layone},96},{{4,vertwo,layone},128},{{5,vertwo,layone},160},{{6,vertwo,layone},192},{{7,vertwo,layone},224},{{8,vertwo,layone},256},{{9,vertwo,layone},288},{{10,vertwo,layone},320},{{11,vertwo,layone},352},{{12,vertwo,layone},384},{{13,vertwo,layone},416},{{14,vertwo,layone},448},{{15,vertwo,layone},bad},
{{0,vertwo,laytwo},free},{{1,vertwo,laytwo},32},{{2,vertwo,laytwo},48},{{3,vertwo,laytwo},56},{{4,vertwo,laytwo},64},{{5,vertwo,laytwo},80},{{6,vertwo,laytwo},96},{{7,vertwo,laytwo},112},{{8,vertwo,laytwo},128},{{9,vertwo,laytwo},160},{{10,vertwo,laytwo},192},{{11,vertwo,laytwo},224},{{12,vertwo,laytwo},256},{{13,vertwo,laytwo},320},{{14,vertwo,laytwo},384},{{15,vertwo,laytwo},bad},
{{0,vertwo,laythr},free},{{1,vertwo,laythr},8},{{2,vertwo,laythr},16},{{3,vertwo,laythr},24},{{4,vertwo,laythr},32},{{5,vertwo,laythr},64},{{6,vertwo,laythr},80},{{7,vertwo,laythr},56},{{8,vertwo,laythr},64},{{9,vertwo,laythr},128},{{10,vertwo,laythr},160},{{11,vertwo,laythr},112},{{12,vertwo,laythr},128},{{13,vertwo,laythr},256},{{14,vertwo,laythr},320},{{15,vertwo,laythr},bad}].

find_sync(Bin,N) ->
	case is_header(N, Bin) of
		{ok, Len1, _} ->
			case is_header(N + Len1, Bin) of
				{ok, Len2, _} ->
					case is_header(N + Len1 + Len2, Bin) of
						{ok, _, Info} ->
							{ok, N, Info};
						error ->
							find_sync(Bin, N+1)
					end;
				error ->
					find_sync(Bin, N+1)
			end;
		error ->
			find_sync(Bin, N+1)
	end.

is_header(N, Bin) ->
	unpack_header(get_word(N, Bin)).

get_word(N, Bin) ->
	{_, <<C:4/binary,_/binary>>} = split_binary(Bin, N),
	C.
unpack_header(X) ->
	try decode_header(X)
	catch
		_:_ -> error
	end.

decode_header(<<2#11111111111:11, B:2, C:2, _D:1, E:4, F:2, G:1, Bits:9>>) ->
	Vsn=case B of
		0 -> {2,5};
		1 -> exit("bad vsn");
		2 -> 2;
		3 -> 1
	end,
	Layer=case C of
		0 -> exit("bad layer");
		1 -> 3;
		2 -> 2;
		3 -> 1
	end,
	%% Protection = D,
	BitRate = bitrate(Vsn, Layer, E) * 1000,
	SampleRate = samplerate(Vsn, F),
	Padding = G,
	FrameLength = trunc(framelength(Vsn, Layer, BitRate, SampleRate, Padding)),
	if
		FrameLength < 21 ->
			exit("frame size");
		true -> 
			{ok, FrameLength, {Vsn, Layer, BitRate, SampleRate, Bits}}
	end;

decode_header(_) ->
	exit("bad header").

bitrate(Vsn, Layer, E) ->
	Da = mapbitratedata(),
	V1 = vermap(Vsn),
	L1 = layermap(Layer),
	Val = lists:keyfind({E,V1,L1}, 1, Da),
	{{E,V1,L1},X} = Val,
	X.

samplerate(Vsn, F) ->
	if 
		Vsn == 1 ->
			case F of
				0 -> 44100;
				1 -> 48000;
				2 -> 32000
			end;
		Vsn == 2 ->
			case F of
				0 -> 22050;
				1 -> 24000;
				2 -> 16000
			end;
		Vsn == {2,5} ->
			case F of
				0 -> 11025;
				1 -> 12000;
				2 -> 8000;
				3 -> exit("bad rate")
			end;
		true ->
			exit("bad smaple rate")
	end.

framelength(Vsn, Layer, BitRate, SampleRate, Padding) ->
	V1 = vermap(Vsn),
	L1 = layermap(Layer),
	if
		{ver,layone} == {V1,L1} ->
			(48 * BitRate)/SampleRate + Padding;
		{ver, laytwo} == {V1, L1} -> 
			(144 * BitRate)/SampleRate + Padding;
		{ver, laythr} == {V1, L1} ->
			(144 * BitRate)/SampleRate + Padding;
		{vertwo, layone} == {V1, L1} ->
			(24 * BitRate)/SampleRate + Padding;
		{vertwo, laytwo} == {V1, L1} ->
			(72 * BitRate)/SampleRate + Padding;       
		{vertwo, laythr} == {V1, L1} ->
			(72 * BitRate)/SampleRate + Padding;
		true ->
			exit("bad frame length")
	end.

vermap(Vsn) ->
	if 
		Vsn == 1 ->
			ver;
		Vsn == 2 ->
			vertwo;
		Vsn == {2,5} ->
			vertwo;
		true ->
			exit("bad vsn")
	end.

layermap(Lay) ->
	if
		Lay == 1 ->
			layone;
		Lay == 2 ->
			laytwo;
		Lay == 3 ->
			laythr;
		true ->
			exit("bad layer")
	end.
























	































