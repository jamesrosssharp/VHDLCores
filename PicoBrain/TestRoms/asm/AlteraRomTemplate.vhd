{begin template}
-- Quartus II VHDL Template
-- Single-Port ROM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity {name} is

  generic
    (
      DATA_WIDTH : natural := 18;
      ADDR_WIDTH : natural := 10
      );

  port
    (
      clk  : in  std_logic;
      addr : in  natural range 0 to 2**ADDR_WIDTH - 1;
      q    : out std_logic_vector((DATA_WIDTH -1) downto 0)
      );

end entity;

architecture rtl of {name} is

  -- Build a 2-D array type for the RoM
  subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
  type memory_t is array(1023 downto 0) of word_t;

  -- Declare the ROM signal and specify a default value.        Quartus II
  -- will create a memory initialization file (.mif) based on the 
  -- default value.
  signal rom : memory_t := ( 
			0 => {INIT_0},
			1 => {INIT_1},
			2 => {INIT_2},
			3 => {INIT_3},
			4 => {INIT_4},
			5 => {INIT_5},
			6 => {INIT_6},
			7 => {INIT_7},
			8 => {INIT_8},
			9 => {INIT_9},
			10 => {INIT_10},
			11 => {INIT_11},
			12 => {INIT_12},
			13 => {INIT_13},
			14 => {INIT_14},
			15 => {INIT_15},
			16 => {INIT_16},
			17 => {INIT_17},
			18 => {INIT_18},
			19 => {INIT_19},
			20 => {INIT_20},
			21 => {INIT_21},
			22 => {INIT_22},
			23 => {INIT_23},
			24 => {INIT_24},
			25 => {INIT_25},
			26 => {INIT_26},
			27 => {INIT_27},
			28 => {INIT_28},
			29 => {INIT_29},
			30 => {INIT_30},
			31 => {INIT_31},
			32 => {INIT_32},
			33 => {INIT_33},
			34 => {INIT_34},
			35 => {INIT_35},
			36 => {INIT_36},
			37 => {INIT_37},
			38 => {INIT_38},
			39 => {INIT_39},
			40 => {INIT_40},
			41 => {INIT_41},
			42 => {INIT_42},
			43 => {INIT_43},
			44 => {INIT_44},
			45 => {INIT_45},
			46 => {INIT_46},
			47 => {INIT_47},
			48 => {INIT_48},
			49 => {INIT_49},
			50 => {INIT_50},
			51 => {INIT_51},
			52 => {INIT_52},
			53 => {INIT_53},
			54 => {INIT_54},
			55 => {INIT_55},
			56 => {INIT_56},
			57 => {INIT_57},
			58 => {INIT_58},
			59 => {INIT_59},
			60 => {INIT_60},
			61 => {INIT_61},
			62 => {INIT_62},
			63 => {INIT_63},
			64 => {INIT_64},
			65 => {INIT_65},
			66 => {INIT_66},
			67 => {INIT_67},
			68 => {INIT_68},
			69 => {INIT_69},
			70 => {INIT_70},
			71 => {INIT_71},
			72 => {INIT_72},
			73 => {INIT_73},
			74 => {INIT_74},
			75 => {INIT_75},
			76 => {INIT_76},
			77 => {INIT_77},
			78 => {INIT_78},
			79 => {INIT_79},
			80 => {INIT_80},
			81 => {INIT_81},
			82 => {INIT_82},
			83 => {INIT_83},
			84 => {INIT_84},
			85 => {INIT_85},
			86 => {INIT_86},
			87 => {INIT_87},
			88 => {INIT_88},
			89 => {INIT_89},
			90 => {INIT_90},
			91 => {INIT_91},
			92 => {INIT_92},
			93 => {INIT_93},
			94 => {INIT_94},
			95 => {INIT_95},
			96 => {INIT_96},
			97 => {INIT_97},
			98 => {INIT_98},
			99 => {INIT_99},
			100 => {INIT_100},
			101 => {INIT_101},
			102 => {INIT_102},
			103 => {INIT_103},
			104 => {INIT_104},
			105 => {INIT_105},
			106 => {INIT_106},
			107 => {INIT_107},
			108 => {INIT_108},
			109 => {INIT_109},
			110 => {INIT_110},
			111 => {INIT_111},
			112 => {INIT_112},
			113 => {INIT_113},
			114 => {INIT_114},
			115 => {INIT_115},
			116 => {INIT_116},
			117 => {INIT_117},
			118 => {INIT_118},
			119 => {INIT_119},
			120 => {INIT_120},
			121 => {INIT_121},
			122 => {INIT_122},
			123 => {INIT_123},
			124 => {INIT_124},
			125 => {INIT_125},
			126 => {INIT_126},
			127 => {INIT_127},
			128 => {INIT_128},
			129 => {INIT_129},
			130 => {INIT_130},
			131 => {INIT_131},
			132 => {INIT_132},
			133 => {INIT_133},
			134 => {INIT_134},
			135 => {INIT_135},
			136 => {INIT_136},
			137 => {INIT_137},
			138 => {INIT_138},
			139 => {INIT_139},
			140 => {INIT_140},
			141 => {INIT_141},
			142 => {INIT_142},
			143 => {INIT_143},
			144 => {INIT_144},
			145 => {INIT_145},
			146 => {INIT_146},
			147 => {INIT_147},
			148 => {INIT_148},
			149 => {INIT_149},
			150 => {INIT_150},
			151 => {INIT_151},
			152 => {INIT_152},
			153 => {INIT_153},
			154 => {INIT_154},
			155 => {INIT_155},
			156 => {INIT_156},
			157 => {INIT_157},
			158 => {INIT_158},
			159 => {INIT_159},
			160 => {INIT_160},
			161 => {INIT_161},
			162 => {INIT_162},
			163 => {INIT_163},
			164 => {INIT_164},
			165 => {INIT_165},
			166 => {INIT_166},
			167 => {INIT_167},
			168 => {INIT_168},
			169 => {INIT_169},
			170 => {INIT_170},
			171 => {INIT_171},
			172 => {INIT_172},
			173 => {INIT_173},
			174 => {INIT_174},
			175 => {INIT_175},
			176 => {INIT_176},
			177 => {INIT_177},
			178 => {INIT_178},
			179 => {INIT_179},
			180 => {INIT_180},
			181 => {INIT_181},
			182 => {INIT_182},
			183 => {INIT_183},
			184 => {INIT_184},
			185 => {INIT_185},
			186 => {INIT_186},
			187 => {INIT_187},
			188 => {INIT_188},
			189 => {INIT_189},
			190 => {INIT_190},
			191 => {INIT_191},
			192 => {INIT_192},
			193 => {INIT_193},
			194 => {INIT_194},
			195 => {INIT_195},
			196 => {INIT_196},
			197 => {INIT_197},
			198 => {INIT_198},
			199 => {INIT_199},
			200 => {INIT_200},
			201 => {INIT_201},
			202 => {INIT_202},
			203 => {INIT_203},
			204 => {INIT_204},
			205 => {INIT_205},
			206 => {INIT_206},
			207 => {INIT_207},
			208 => {INIT_208},
			209 => {INIT_209},
			210 => {INIT_210},
			211 => {INIT_211},
			212 => {INIT_212},
			213 => {INIT_213},
			214 => {INIT_214},
			215 => {INIT_215},
			216 => {INIT_216},
			217 => {INIT_217},
			218 => {INIT_218},
			219 => {INIT_219},
			220 => {INIT_220},
			221 => {INIT_221},
			222 => {INIT_222},
			223 => {INIT_223},
			224 => {INIT_224},
			225 => {INIT_225},
			226 => {INIT_226},
			227 => {INIT_227},
			228 => {INIT_228},
			229 => {INIT_229},
			230 => {INIT_230},
			231 => {INIT_231},
			232 => {INIT_232},
			233 => {INIT_233},
			234 => {INIT_234},
			235 => {INIT_235},
			236 => {INIT_236},
			237 => {INIT_237},
			238 => {INIT_238},
			239 => {INIT_239},
			240 => {INIT_240},
			241 => {INIT_241},
			242 => {INIT_242},
			243 => {INIT_243},
			244 => {INIT_244},
			245 => {INIT_245},
			246 => {INIT_246},
			247 => {INIT_247},
			248 => {INIT_248},
			249 => {INIT_249},
			250 => {INIT_250},
			251 => {INIT_251},
			252 => {INIT_252},
			253 => {INIT_253},
			254 => {INIT_254},
			255 => {INIT_255},
			256 => {INIT_256},
			257 => {INIT_257},
			258 => {INIT_258},
			259 => {INIT_259},
			260 => {INIT_260},
			261 => {INIT_261},
			262 => {INIT_262},
			263 => {INIT_263},
			264 => {INIT_264},
			265 => {INIT_265},
			266 => {INIT_266},
			267 => {INIT_267},
			268 => {INIT_268},
			269 => {INIT_269},
			270 => {INIT_270},
			271 => {INIT_271},
			272 => {INIT_272},
			273 => {INIT_273},
			274 => {INIT_274},
			275 => {INIT_275},
			276 => {INIT_276},
			277 => {INIT_277},
			278 => {INIT_278},
			279 => {INIT_279},
			280 => {INIT_280},
			281 => {INIT_281},
			282 => {INIT_282},
			283 => {INIT_283},
			284 => {INIT_284},
			285 => {INIT_285},
			286 => {INIT_286},
			287 => {INIT_287},
			288 => {INIT_288},
			289 => {INIT_289},
			290 => {INIT_290},
			291 => {INIT_291},
			292 => {INIT_292},
			293 => {INIT_293},
			294 => {INIT_294},
			295 => {INIT_295},
			296 => {INIT_296},
			297 => {INIT_297},
			298 => {INIT_298},
			299 => {INIT_299},
			300 => {INIT_300},
			301 => {INIT_301},
			302 => {INIT_302},
			303 => {INIT_303},
			304 => {INIT_304},
			305 => {INIT_305},
			306 => {INIT_306},
			307 => {INIT_307},
			308 => {INIT_308},
			309 => {INIT_309},
			310 => {INIT_310},
			311 => {INIT_311},
			312 => {INIT_312},
			313 => {INIT_313},
			314 => {INIT_314},
			315 => {INIT_315},
			316 => {INIT_316},
			317 => {INIT_317},
			318 => {INIT_318},
			319 => {INIT_319},
			320 => {INIT_320},
			321 => {INIT_321},
			322 => {INIT_322},
			323 => {INIT_323},
			324 => {INIT_324},
			325 => {INIT_325},
			326 => {INIT_326},
			327 => {INIT_327},
			328 => {INIT_328},
			329 => {INIT_329},
			330 => {INIT_330},
			331 => {INIT_331},
			332 => {INIT_332},
			333 => {INIT_333},
			334 => {INIT_334},
			335 => {INIT_335},
			336 => {INIT_336},
			337 => {INIT_337},
			338 => {INIT_338},
			339 => {INIT_339},
			340 => {INIT_340},
			341 => {INIT_341},
			342 => {INIT_342},
			343 => {INIT_343},
			344 => {INIT_344},
			345 => {INIT_345},
			346 => {INIT_346},
			347 => {INIT_347},
			348 => {INIT_348},
			349 => {INIT_349},
			350 => {INIT_350},
			351 => {INIT_351},
			352 => {INIT_352},
			353 => {INIT_353},
			354 => {INIT_354},
			355 => {INIT_355},
			356 => {INIT_356},
			357 => {INIT_357},
			358 => {INIT_358},
			359 => {INIT_359},
			360 => {INIT_360},
			361 => {INIT_361},
			362 => {INIT_362},
			363 => {INIT_363},
			364 => {INIT_364},
			365 => {INIT_365},
			366 => {INIT_366},
			367 => {INIT_367},
			368 => {INIT_368},
			369 => {INIT_369},
			370 => {INIT_370},
			371 => {INIT_371},
			372 => {INIT_372},
			373 => {INIT_373},
			374 => {INIT_374},
			375 => {INIT_375},
			376 => {INIT_376},
			377 => {INIT_377},
			378 => {INIT_378},
			379 => {INIT_379},
			380 => {INIT_380},
			381 => {INIT_381},
			382 => {INIT_382},
			383 => {INIT_383},
			384 => {INIT_384},
			385 => {INIT_385},
			386 => {INIT_386},
			387 => {INIT_387},
			388 => {INIT_388},
			389 => {INIT_389},
			390 => {INIT_390},
			391 => {INIT_391},
			392 => {INIT_392},
			393 => {INIT_393},
			394 => {INIT_394},
			395 => {INIT_395},
			396 => {INIT_396},
			397 => {INIT_397},
			398 => {INIT_398},
			399 => {INIT_399},
			400 => {INIT_400},
			401 => {INIT_401},
			402 => {INIT_402},
			403 => {INIT_403},
			404 => {INIT_404},
			405 => {INIT_405},
			406 => {INIT_406},
			407 => {INIT_407},
			408 => {INIT_408},
			409 => {INIT_409},
			410 => {INIT_410},
			411 => {INIT_411},
			412 => {INIT_412},
			413 => {INIT_413},
			414 => {INIT_414},
			415 => {INIT_415},
			416 => {INIT_416},
			417 => {INIT_417},
			418 => {INIT_418},
			419 => {INIT_419},
			420 => {INIT_420},
			421 => {INIT_421},
			422 => {INIT_422},
			423 => {INIT_423},
			424 => {INIT_424},
			425 => {INIT_425},
			426 => {INIT_426},
			427 => {INIT_427},
			428 => {INIT_428},
			429 => {INIT_429},
			430 => {INIT_430},
			431 => {INIT_431},
			432 => {INIT_432},
			433 => {INIT_433},
			434 => {INIT_434},
			435 => {INIT_435},
			436 => {INIT_436},
			437 => {INIT_437},
			438 => {INIT_438},
			439 => {INIT_439},
			440 => {INIT_440},
			441 => {INIT_441},
			442 => {INIT_442},
			443 => {INIT_443},
			444 => {INIT_444},
			445 => {INIT_445},
			446 => {INIT_446},
			447 => {INIT_447},
			448 => {INIT_448},
			449 => {INIT_449},
			450 => {INIT_450},
			451 => {INIT_451},
			452 => {INIT_452},
			453 => {INIT_453},
			454 => {INIT_454},
			455 => {INIT_455},
			456 => {INIT_456},
			457 => {INIT_457},
			458 => {INIT_458},
			459 => {INIT_459},
			460 => {INIT_460},
			461 => {INIT_461},
			462 => {INIT_462},
			463 => {INIT_463},
			464 => {INIT_464},
			465 => {INIT_465},
			466 => {INIT_466},
			467 => {INIT_467},
			468 => {INIT_468},
			469 => {INIT_469},
			470 => {INIT_470},
			471 => {INIT_471},
			472 => {INIT_472},
			473 => {INIT_473},
			474 => {INIT_474},
			475 => {INIT_475},
			476 => {INIT_476},
			477 => {INIT_477},
			478 => {INIT_478},
			479 => {INIT_479},
			480 => {INIT_480},
			481 => {INIT_481},
			482 => {INIT_482},
			483 => {INIT_483},
			484 => {INIT_484},
			485 => {INIT_485},
			486 => {INIT_486},
			487 => {INIT_487},
			488 => {INIT_488},
			489 => {INIT_489},
			490 => {INIT_490},
			491 => {INIT_491},
			492 => {INIT_492},
			493 => {INIT_493},
			494 => {INIT_494},
			495 => {INIT_495},
			496 => {INIT_496},
			497 => {INIT_497},
			498 => {INIT_498},
			499 => {INIT_499},
			500 => {INIT_500},
			501 => {INIT_501},
			502 => {INIT_502},
			503 => {INIT_503},
			504 => {INIT_504},
			505 => {INIT_505},
			506 => {INIT_506},
			507 => {INIT_507},
			508 => {INIT_508},
			509 => {INIT_509},
			510 => {INIT_510},
			511 => {INIT_511},
			512 => {INIT_512},
			513 => {INIT_513},
			514 => {INIT_514},
			515 => {INIT_515},
			516 => {INIT_516},
			517 => {INIT_517},
			518 => {INIT_518},
			519 => {INIT_519},
			520 => {INIT_520},
			521 => {INIT_521},
			522 => {INIT_522},
			523 => {INIT_523},
			524 => {INIT_524},
			525 => {INIT_525},
			526 => {INIT_526},
			527 => {INIT_527},
			528 => {INIT_528},
			529 => {INIT_529},
			530 => {INIT_530},
			531 => {INIT_531},
			532 => {INIT_532},
			533 => {INIT_533},
			534 => {INIT_534},
			535 => {INIT_535},
			536 => {INIT_536},
			537 => {INIT_537},
			538 => {INIT_538},
			539 => {INIT_539},
			540 => {INIT_540},
			541 => {INIT_541},
			542 => {INIT_542},
			543 => {INIT_543},
			544 => {INIT_544},
			545 => {INIT_545},
			546 => {INIT_546},
			547 => {INIT_547},
			548 => {INIT_548},
			549 => {INIT_549},
			550 => {INIT_550},
			551 => {INIT_551},
			552 => {INIT_552},
			553 => {INIT_553},
			554 => {INIT_554},
			555 => {INIT_555},
			556 => {INIT_556},
			557 => {INIT_557},
			558 => {INIT_558},
			559 => {INIT_559},
			560 => {INIT_560},
			561 => {INIT_561},
			562 => {INIT_562},
			563 => {INIT_563},
			564 => {INIT_564},
			565 => {INIT_565},
			566 => {INIT_566},
			567 => {INIT_567},
			568 => {INIT_568},
			569 => {INIT_569},
			570 => {INIT_570},
			571 => {INIT_571},
			572 => {INIT_572},
			573 => {INIT_573},
			574 => {INIT_574},
			575 => {INIT_575},
			576 => {INIT_576},
			577 => {INIT_577},
			578 => {INIT_578},
			579 => {INIT_579},
			580 => {INIT_580},
			581 => {INIT_581},
			582 => {INIT_582},
			583 => {INIT_583},
			584 => {INIT_584},
			585 => {INIT_585},
			586 => {INIT_586},
			587 => {INIT_587},
			588 => {INIT_588},
			589 => {INIT_589},
			590 => {INIT_590},
			591 => {INIT_591},
			592 => {INIT_592},
			593 => {INIT_593},
			594 => {INIT_594},
			595 => {INIT_595},
			596 => {INIT_596},
			597 => {INIT_597},
			598 => {INIT_598},
			599 => {INIT_599},
			600 => {INIT_600},
			601 => {INIT_601},
			602 => {INIT_602},
			603 => {INIT_603},
			604 => {INIT_604},
			605 => {INIT_605},
			606 => {INIT_606},
			607 => {INIT_607},
			608 => {INIT_608},
			609 => {INIT_609},
			610 => {INIT_610},
			611 => {INIT_611},
			612 => {INIT_612},
			613 => {INIT_613},
			614 => {INIT_614},
			615 => {INIT_615},
			616 => {INIT_616},
			617 => {INIT_617},
			618 => {INIT_618},
			619 => {INIT_619},
			620 => {INIT_620},
			621 => {INIT_621},
			622 => {INIT_622},
			623 => {INIT_623},
			624 => {INIT_624},
			625 => {INIT_625},
			626 => {INIT_626},
			627 => {INIT_627},
			628 => {INIT_628},
			629 => {INIT_629},
			630 => {INIT_630},
			631 => {INIT_631},
			632 => {INIT_632},
			633 => {INIT_633},
			634 => {INIT_634},
			635 => {INIT_635},
			636 => {INIT_636},
			637 => {INIT_637},
			638 => {INIT_638},
			639 => {INIT_639},
			640 => {INIT_640},
			641 => {INIT_641},
			642 => {INIT_642},
			643 => {INIT_643},
			644 => {INIT_644},
			645 => {INIT_645},
			646 => {INIT_646},
			647 => {INIT_647},
			648 => {INIT_648},
			649 => {INIT_649},
			650 => {INIT_650},
			651 => {INIT_651},
			652 => {INIT_652},
			653 => {INIT_653},
			654 => {INIT_654},
			655 => {INIT_655},
			656 => {INIT_656},
			657 => {INIT_657},
			658 => {INIT_658},
			659 => {INIT_659},
			660 => {INIT_660},
			661 => {INIT_661},
			662 => {INIT_662},
			663 => {INIT_663},
			664 => {INIT_664},
			665 => {INIT_665},
			666 => {INIT_666},
			667 => {INIT_667},
			668 => {INIT_668},
			669 => {INIT_669},
			670 => {INIT_670},
			671 => {INIT_671},
			672 => {INIT_672},
			673 => {INIT_673},
			674 => {INIT_674},
			675 => {INIT_675},
			676 => {INIT_676},
			677 => {INIT_677},
			678 => {INIT_678},
			679 => {INIT_679},
			680 => {INIT_680},
			681 => {INIT_681},
			682 => {INIT_682},
			683 => {INIT_683},
			684 => {INIT_684},
			685 => {INIT_685},
			686 => {INIT_686},
			687 => {INIT_687},
			688 => {INIT_688},
			689 => {INIT_689},
			690 => {INIT_690},
			691 => {INIT_691},
			692 => {INIT_692},
			693 => {INIT_693},
			694 => {INIT_694},
			695 => {INIT_695},
			696 => {INIT_696},
			697 => {INIT_697},
			698 => {INIT_698},
			699 => {INIT_699},
			700 => {INIT_700},
			701 => {INIT_701},
			702 => {INIT_702},
			703 => {INIT_703},
			704 => {INIT_704},
			705 => {INIT_705},
			706 => {INIT_706},
			707 => {INIT_707},
			708 => {INIT_708},
			709 => {INIT_709},
			710 => {INIT_710},
			711 => {INIT_711},
			712 => {INIT_712},
			713 => {INIT_713},
			714 => {INIT_714},
			715 => {INIT_715},
			716 => {INIT_716},
			717 => {INIT_717},
			718 => {INIT_718},
			719 => {INIT_719},
			720 => {INIT_720},
			721 => {INIT_721},
			722 => {INIT_722},
			723 => {INIT_723},
			724 => {INIT_724},
			725 => {INIT_725},
			726 => {INIT_726},
			727 => {INIT_727},
			728 => {INIT_728},
			729 => {INIT_729},
			730 => {INIT_730},
			731 => {INIT_731},
			732 => {INIT_732},
			733 => {INIT_733},
			734 => {INIT_734},
			735 => {INIT_735},
			736 => {INIT_736},
			737 => {INIT_737},
			738 => {INIT_738},
			739 => {INIT_739},
			740 => {INIT_740},
			741 => {INIT_741},
			742 => {INIT_742},
			743 => {INIT_743},
			744 => {INIT_744},
			745 => {INIT_745},
			746 => {INIT_746},
			747 => {INIT_747},
			748 => {INIT_748},
			749 => {INIT_749},
			750 => {INIT_750},
			751 => {INIT_751},
			752 => {INIT_752},
			753 => {INIT_753},
			754 => {INIT_754},
			755 => {INIT_755},
			756 => {INIT_756},
			757 => {INIT_757},
			758 => {INIT_758},
			759 => {INIT_759},
			760 => {INIT_760},
			761 => {INIT_761},
			762 => {INIT_762},
			763 => {INIT_763},
			764 => {INIT_764},
			765 => {INIT_765},
			766 => {INIT_766},
			767 => {INIT_767},
			768 => {INIT_768},
			769 => {INIT_769},
			770 => {INIT_770},
			771 => {INIT_771},
			772 => {INIT_772},
			773 => {INIT_773},
			774 => {INIT_774},
			775 => {INIT_775},
			776 => {INIT_776},
			777 => {INIT_777},
			778 => {INIT_778},
			779 => {INIT_779},
			780 => {INIT_780},
			781 => {INIT_781},
			782 => {INIT_782},
			783 => {INIT_783},
			784 => {INIT_784},
			785 => {INIT_785},
			786 => {INIT_786},
			787 => {INIT_787},
			788 => {INIT_788},
			789 => {INIT_789},
			790 => {INIT_790},
			791 => {INIT_791},
			792 => {INIT_792},
			793 => {INIT_793},
			794 => {INIT_794},
			795 => {INIT_795},
			796 => {INIT_796},
			797 => {INIT_797},
			798 => {INIT_798},
			799 => {INIT_799},
			800 => {INIT_800},
			801 => {INIT_801},
			802 => {INIT_802},
			803 => {INIT_803},
			804 => {INIT_804},
			805 => {INIT_805},
			806 => {INIT_806},
			807 => {INIT_807},
			808 => {INIT_808},
			809 => {INIT_809},
			810 => {INIT_810},
			811 => {INIT_811},
			812 => {INIT_812},
			813 => {INIT_813},
			814 => {INIT_814},
			815 => {INIT_815},
			816 => {INIT_816},
			817 => {INIT_817},
			818 => {INIT_818},
			819 => {INIT_819},
			820 => {INIT_820},
			821 => {INIT_821},
			822 => {INIT_822},
			823 => {INIT_823},
			824 => {INIT_824},
			825 => {INIT_825},
			826 => {INIT_826},
			827 => {INIT_827},
			828 => {INIT_828},
			829 => {INIT_829},
			830 => {INIT_830},
			831 => {INIT_831},
			832 => {INIT_832},
			833 => {INIT_833},
			834 => {INIT_834},
			835 => {INIT_835},
			836 => {INIT_836},
			837 => {INIT_837},
			838 => {INIT_838},
			839 => {INIT_839},
			840 => {INIT_840},
			841 => {INIT_841},
			842 => {INIT_842},
			843 => {INIT_843},
			844 => {INIT_844},
			845 => {INIT_845},
			846 => {INIT_846},
			847 => {INIT_847},
			848 => {INIT_848},
			849 => {INIT_849},
			850 => {INIT_850},
			851 => {INIT_851},
			852 => {INIT_852},
			853 => {INIT_853},
			854 => {INIT_854},
			855 => {INIT_855},
			856 => {INIT_856},
			857 => {INIT_857},
			858 => {INIT_858},
			859 => {INIT_859},
			860 => {INIT_860},
			861 => {INIT_861},
			862 => {INIT_862},
			863 => {INIT_863},
			864 => {INIT_864},
			865 => {INIT_865},
			866 => {INIT_866},
			867 => {INIT_867},
			868 => {INIT_868},
			869 => {INIT_869},
			870 => {INIT_870},
			871 => {INIT_871},
			872 => {INIT_872},
			873 => {INIT_873},
			874 => {INIT_874},
			875 => {INIT_875},
			876 => {INIT_876},
			877 => {INIT_877},
			878 => {INIT_878},
			879 => {INIT_879},
			880 => {INIT_880},
			881 => {INIT_881},
			882 => {INIT_882},
			883 => {INIT_883},
			884 => {INIT_884},
			885 => {INIT_885},
			886 => {INIT_886},
			887 => {INIT_887},
			888 => {INIT_888},
			889 => {INIT_889},
			890 => {INIT_890},
			891 => {INIT_891},
			892 => {INIT_892},
			893 => {INIT_893},
			894 => {INIT_894},
			895 => {INIT_895},
			896 => {INIT_896},
			897 => {INIT_897},
			898 => {INIT_898},
			899 => {INIT_899},
			900 => {INIT_900},
			901 => {INIT_901},
			902 => {INIT_902},
			903 => {INIT_903},
			904 => {INIT_904},
			905 => {INIT_905},
			906 => {INIT_906},
			907 => {INIT_907},
			908 => {INIT_908},
			909 => {INIT_909},
			910 => {INIT_910},
			911 => {INIT_911},
			912 => {INIT_912},
			913 => {INIT_913},
			914 => {INIT_914},
			915 => {INIT_915},
			916 => {INIT_916},
			917 => {INIT_917},
			918 => {INIT_918},
			919 => {INIT_919},
			920 => {INIT_920},
			921 => {INIT_921},
			922 => {INIT_922},
			923 => {INIT_923},
			924 => {INIT_924},
			925 => {INIT_925},
			926 => {INIT_926},
			927 => {INIT_927},
			928 => {INIT_928},
			929 => {INIT_929},
			930 => {INIT_930},
			931 => {INIT_931},
			932 => {INIT_932},
			933 => {INIT_933},
			934 => {INIT_934},
			935 => {INIT_935},
			936 => {INIT_936},
			937 => {INIT_937},
			938 => {INIT_938},
			939 => {INIT_939},
			940 => {INIT_940},
			941 => {INIT_941},
			942 => {INIT_942},
			943 => {INIT_943},
			944 => {INIT_944},
			945 => {INIT_945},
			946 => {INIT_946},
			947 => {INIT_947},
			948 => {INIT_948},
			949 => {INIT_949},
			950 => {INIT_950},
			951 => {INIT_951},
			952 => {INIT_952},
			953 => {INIT_953},
			954 => {INIT_954},
			955 => {INIT_955},
			956 => {INIT_956},
			957 => {INIT_957},
			958 => {INIT_958},
			959 => {INIT_959},
			960 => {INIT_960},
			961 => {INIT_961},
			962 => {INIT_962},
			963 => {INIT_963},
			964 => {INIT_964},
			965 => {INIT_965},
			966 => {INIT_966},
			967 => {INIT_967},
			968 => {INIT_968},
			969 => {INIT_969},
			970 => {INIT_970},
			971 => {INIT_971},
			972 => {INIT_972},
			973 => {INIT_973},
			974 => {INIT_974},
			975 => {INIT_975},
			976 => {INIT_976},
			977 => {INIT_977},
			978 => {INIT_978},
			979 => {INIT_979},
			980 => {INIT_980},
			981 => {INIT_981},
			982 => {INIT_982},
			983 => {INIT_983},
			984 => {INIT_984},
			985 => {INIT_985},
			986 => {INIT_986},
			987 => {INIT_987},
			988 => {INIT_988},
			989 => {INIT_989},
			990 => {INIT_990},
			991 => {INIT_991},
			992 => {INIT_992},
			993 => {INIT_993},
			994 => {INIT_994},
			995 => {INIT_995},
			996 => {INIT_996},
			997 => {INIT_997},
			998 => {INIT_998},
			999 => {INIT_999},
			1000 => {INIT_1000},
			1001 => {INIT_1001},
			1002 => {INIT_1002},
			1003 => {INIT_1003},
			1004 => {INIT_1004},
			1005 => {INIT_1005},
			1006 => {INIT_1006},
			1007 => {INIT_1007},
			1008 => {INIT_1008},
			1009 => {INIT_1009},
			1010 => {INIT_1010},
			1011 => {INIT_1011},
			1012 => {INIT_1012},
			1013 => {INIT_1013},
			1014 => {INIT_1014},
			1015 => {INIT_1015},
			1016 => {INIT_1016},
			1017 => {INIT_1017},
			1018 => {INIT_1018},
			1019 => {INIT_1019},
			1020 => {INIT_1020},
			1021 => {INIT_1021},
			1022 => {INIT_1022},
			1023 => {INIT_1023}
						    );

begin

  process(clk)
  begin
    if(rising_edge(clk)) then
      q <= rom(addr);
    end if;
  end process;

end rtl;
