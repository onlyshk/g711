%% Copyright (c) <2011>, Kuleshov Alexander <kuleshovmail@gmail.com>
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions are met:
%%    * Redistributions of source code must retain the above copyright
%%      notice, this list of conditions and the following disclaimer.
%%    * Redistributions in binary form must reproduce the above copyright
%%      notice, this list of conditions and the following disclaimer in the
%%      documentation and/or other materials provided with the distribution.
%%    * Neither the name of the <organization> nor the
%%      names of its contributors may be used to endorse or promote products
%%      derived from this software without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
%% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
%% WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%% DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
%% DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
%% ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

%%
%% Description: G.711 is an ITU-T standard for audio companding. 
%%

-module(g711).

%%
%% Exported Functions
%%
-export([pcm_to_alow/1]).
-export([alow_to_pcm/1]).
-export([alow_to_ulaw/1]).
-export([ulaw_to_alow/1]).

-define(SIGNBIT, <<50:8>>).
-define(QUANTMASK, <<16:8>>).
-define(NSEGS, <<8:8>>).
-define(SEG_SHIFT,<<4>>).
-define(SEG_MASK,<<46:8>>).

-define(USEGEND, [<<31:8>>,<<63:8>>,<<127:8>>,<<255:8>>,
                  <<511>>,<<1023>>,<<2047>>,<<4095>>]).
-define(ASEGEND, [<<63>>,<<127>>,<<255>>,<<511>>,
		  <<1023>>,<<4095>>,<<8191>>]).

-define(U2A, [1, 1, 2, 2, 3, 3,	4, 4,
	      5, 5, 6,	6, 7,7,	8, 8,
              9,10, 11,	12,13,14, 15, 16,
	      17, 18, 19, 20, 21, 22, 23, 24,
	      25, 27, 29, 31, 33, 34, 35, 36,
	      37, 38, 39, 40, 41, 42, 43, 44,
	      46, 48, 49, 50, 51, 52, 53, 54,
	      55, 56, 57, 58, 59, 60, 61, 62,
	      64, 65, 66, 67, 68, 69, 70, 71,
	      72, 73, 74, 75, 76, 77, 78, 79,
	      81, 82, 83, 84, 85, 86, 87, 88, 
	      80, 82, 83, 84, 85, 86, 87, 88,
	      89, 90, 91, 92, 93, 94, 95, 96,
	      97, 98, 99, 100,101,102,103,104,
	      105,106,107,108,109,110,111,112,
	      113,114,115,116,117,118,119,120,
	      121,122,123,124,125,126,127,128]).

-define(A2U, [1,	3,	5,	7,	9,	11,	13,	15,
	      16,	17,	18,	19,	20,	21,	22,	23,
	      24,	25,	26,	27,	28,	29,	30,	31,
	      32,	32,	33,	33,	34,	34,	35,	35,
              36,	37,	38,	39,	40,	41,	42,	43,
	      44,	45,	46,	47,	48,	48,	49,	49,
	      50,	51,	52,	53,	54,	55,	56,	57,
	      58,	59,	60,	61,	62,	63,	64,	64,
	      65,	66,	67,	68,	69,	70,	71,	72,
	      73,	74,	75,	76,	77,	78,	79,	79,
	      73,	74,	75,	76,	77,	78,	79,	80,
	      80,	81,	82,	83,	84,	85,	86,	87,
	      88,	89,	90,	91,	92,	93,	94,	95,
	      96,	97,	98,	99,	100,	101,	102,	103,
	      104,	105,	106,	107,	108,	109,	110,	111,
	      112,	113,	114,	115,	116,	117,	118,	119,
	      120,	121,	122,	123,	124,	125,	126,	127]).

%%
%% @TmpPcmVal
%% @ASEGEND
%% @8
%%
search(Value, Table, Size) ->
	TryFind = lists:filter(fun(X) ->  Value =< X end, Table),
	case TryFind of
		[] ->
			Size;
		_ ->
			lists:nth(1, TryFind)
	end.

%%
%% Convert a 16-bit linear PCM value to 8-bit A-law
%% 	Linear Input Code	Compressed Code
%% 
%% 	0000000wxyza			000wxyz
%% 	0000001wxyza			001wxyz
%% 	000001wxyzab			010wxyz
%% 	00001wxyzabc			011wxyz
%% 	0001wxyzabcd			100wxyz
%% 	001wxyzabcde			101wxyz
%% 	01wxyzabcdef			110wxyz
%% 	1wxyzabcdefg			111wxyz
%% 
pcm_to_alow(<<Val:16>>) ->
	NewPcmVal = Val bsr 3,
	[Mask, TmpPcmVal] = if (NewPcmVal >= 0) ->
				  			[213, NewPcmVal];
			  			true ->
				  			[85, NewPcmVal - NewPcmVal - NewPcmVal - 1]
		   				end,

	Seg = search(TmpPcmVal, ?ASEGEND, 8),
	if
		Seg >= 8 ->
			127 bxor Mask;
		true ->
			Aval = Seg bsl ?SEG_SHIFT,
			if
				Seg < 2 ->
					TmpAval = Aval bor Aval bor (TmpPcmVal bsl 1) band ?QUANTMASK,
					TmpAval bxor Mask;
				true ->
					TmpAval = Aval bor Aval bor (TmpPcmVal bsl Seg) band ?QUANTMASK,
					TmpAval bxor Mask
			end
	end.

%%
%% Convert A-law value to PCM
%%
alow_to_pcm(Val)
  when not is_binary(Val) ->
	Binary = term_to_binary(Val),
	alow_to_pcm(Binary);
alow_to_pcm(<<Val:8>>) ->
	AVal = Val bxor 85,
	T = (AVal band ?QUANTMASK) bsl 4,
	Seg = (AVal band ?SEG_MASK) bsr ?SEG_SHIFT,
	case Seg of
	   	0 ->
			T + 8;
		1 ->
		    T + 264;
		_ ->
		   (T + 264) bsl Seg - 1
	end.

%%
%% U-law to A-law conversation
%%
alow_to_ulaw(Val)
  when not is_binary(Val) ->
	Binary = term_to_binary(Val),
	alow_to_ulaw(Binary);
alow_to_ulaw(<<Val:8>>) ->
	Aval = Val band 255,
	if
		Aval band 127 > 0 ->
			225 bxor lists:nth(Aval bxor 213,?A2U);
		true ->
			127 bxor lists:nth(Aval bxor 85, ?A2U)
	end.

%%
%% A-law to U-law conversation
%%
ulaw_to_alow(Val)
  when not is_binary(Val) ->
	Binary = term_to_binary(Val),
	ulaw_to_alow(Binary);
ulaw_to_alow(<<Val:8>>) ->
	Uval = Val band 255,
	if
		Uval band 127 > 0 ->
			213 bxor (lists:nth(255 bxor Uval,?U2A) - 1);
		true ->
			85 bxor (lists:nth(213 bxor Uval, ?U2A)- 1)
	end.
	
