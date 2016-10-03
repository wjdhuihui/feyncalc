(* ::Package:: *)

(* ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ *)

(* :Title: DiracTrace														*)

(*
	This software is covered by the GNU General Public License 3.
	Copyright (C) 1990-2016 Rolf Mertig
	Copyright (C) 1997-2016 Frederik Orellana
	Copyright (C) 2014-2016 Vladyslav Shtabovenko
*)

(* :Summary:  Dirac trace calculation										*)

(* ------------------------------------------------------------------------ *)


DiracTrace::usage =
"DiracTrace[expr] is the head of Dirac traces. \
Whether the trace is  evaluated depends on the option \
DiracTraceEvaluate. See also TR. \
The argument expr may be a product of Dirac matrices or slashes \
separated by the Mathematica Dot \".\" (assuming DOT has been set to Dot).
The option Factoring determines the final function to be applied. If \
it is set to False no simplification is done. \
It might be set to, e.g., Factor or Factor2 to get simpler results. \
With the default setting Factoring -> Automatic factorization is performed on \
not too long (LeafCount[ ] < 5000 ) expressions.
";

DiracTrace::noncom =
"Wrong syntax! The Dirac trace of `1` contains Dirac matrices multiplied via \
Times (commutative multiplication) instead of DOT (non-commutative multiplication). \
Evaluation aborted!";


DiracTrace::ndranomaly =
"You are using naive dimensional regularization (NDR), such that in D dimensions \
gamma^5 anticommutes with all other Dirac matrices. In this scheme \
(without additional prescriptions) it is not possible to compute traces with an \
odd number of gamma^5 unambiguously. The trace of `1` is illegal in NDR. \
Evaluation aborted!";

DiracTrace::ilsch =
"The settings $BreitMaison=`1`, $Larin=`2` do not describe a valid \
scheme for treating gamma^5 in D dimensions. Evaluation aborted!.";

DiracTrace::fail =
"DiracTrace failed to compute the trace of `1`. Evaluation aborted!.";

DiracTrace::rem =
"Error! The trace of the original expression still contains Dirac matrices. \
Evaluation aborted!.";

DiracTrace::failmsg =
"Error! DiracTrace has encountered a fatal problem and must abort the computation. \
The problem reads: `1`"

(* ------------------------------------------------------------------------ *)

Begin["`Package`"]

(*spursav is also used in TR*)
spursav

End[]

Begin["`DiracTrace`Private`"]

diTrVerbose::usage="";
west::usage="";
unitMatrixTrace::usage="";
traceNo5Fun::usage="";
trace5Fun::usage="";

Options[DiracTrace] = {
	Contract -> 400000,
	EpsContract -> False,
	Expand -> True,
	Factoring -> Automatic,
	FeynCalcExternal -> False,
	FeynCalcInternal -> False,
	Mandelstam    -> {},
	PairCollect    -> False,
	DiracTraceEvaluate-> False,
	Schouten-> 0,
	TraceOfOne -> 4,
	FCVerbose -> False,
	West -> True
};


DiracTrace /:
	MakeBoxes[DiracTrace[expr__, OptionsPattern[]], TraditionalForm]:=
	RowBox[{"tr","(",TBox[expr], ")"}]


(* gamma67backdef: reinsertion of gamma6 and gamm7 *)
gamma67back[x_] :=
	x/.DiracGamma[6]->( 1/2 + DiracGamma[5]/2 )/. DiracGamma[7]->( 1/2 - DiracGamma[5]/2 );

DiracTrace[0, OptionsPattern[]] :=
	0;

DiracTrace[a_ /; (FreeQ[a, DiracGamma] && !FreeQ[a, DiracGammaT]), b:OptionsPattern[]] :=
	DiracTrace[(a//Transpose)//Reverse, b];

DiracTrace[a:Except[_HoldAll]..., x_,y_, z___] :=
	DiracTrace[a,x.y,z]/;FreeQ2[y,{Rule,BlankNullSequence}]&& FreeQ2[x,{Rule,BlankNullSequence}];

DiracTrace[expr_, op:OptionsPattern[]] :=
	Block[ {diTres, ex, tr1,tr2,tr3,time,dsHead,diracObjects,diracObjectsEval,null1,null2,freePart,dsPart,repRule},


		If [OptionValue[FCVerbose]===False,
			diTrVerbose=$VeryVerbose,
			If[MatchQ[OptionValue[FCVerbose], _Integer?Positive | 0],
				diTrVerbose=OptionValue[FCVerbose]
			];
		];

		unitMatrixTrace = OptionValue[TraceOfOne];

		FCPrint[1, "DiracTrace. Entering.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrace: Entering with ", expr, FCDoControl->diTrVerbose];


		If[ OptionValue[FCI],
			ex = expr,
			ex = FCI[expr]
		];
		(*
		time=AbsoluteTime[];
		FCPrint[1, "DiracTrace. Checking the syntax.", FCDoControl->diTrVerbose];
		If [ !FreeQ2[ex,
			{
			(*Times instead of DOT between two Dirac or SU(N) matrices*)
			(DiracGamma | DiracGammaT)[a__]*(DiracGamma | DiracGammaT)[b__],
			SUNT[a__]*SUNT[b__],
			(*Two DOT objects multiplied with each other via Times, unless those are closed spinor chains*)
			DOT[a:Except[_Spinor]...,(DiracGamma | DiracGammaT )[b__],c:Except[_Spinor]...]*
			DOT[d:Except[_Spinor]...,(DiracGamma | DiracGammaT)[e__],f:Except[_Spinor]...],
			(*Open spinor chains*)
			DOT[a_Spinor,b:Except[_Spinor]...],
			(*DOT object multiplied by a Dirac or SU(N) matrix via Times*)
			DOT[a:Except[_Spinor]...,(DiracGamma | DiracGammaT)[b__],c:Except[_Spinor]...]*
			(DiracGamma | DiracGammaT)[d__]}],
			Message[DiracTrace::noncom, InputForm[ex]];
			Abort[]
		];
		FCPrint[1,"DiracTrace: Syntax check done, timing: ", N[AbsoluteTime[] - time, 4] , FCDoControl->diTrVerbose];
		*)

		(* Doing contractions can often simplify the underlying expression *)
		time=AbsoluteTime[];
		FCPrint[1, "DiracTrace. Applying Contract.", FCDoControl->diTrVerbose];
		If[	Contract=!=False,
			ex = Contract[ex, Expanding->True, EpsContract-> OptionValue[EpsContract], Factoring->False];
		];

		FCPrint[1,"DiracTrace: Contract done, timing: ", N[AbsoluteTime[] - time, 4] , FCDoControl->diTrVerbose];

		(* 	First of all we need to extract all the Dirac structures inside the trace. *)
		ex = FCDiracIsolate[ex,FCI->True,Head->dsHead, Spinor->False];


		{freePart,dsPart} = FCSplit[ex,{dsHead}];
		FCPrint[3,"DiracTrace: dsPart: ",dsPart , FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: freePart: ",freePart , FCDoControl->diTrVerbose];
		If [ dsPart=!=0,
			(* Check that there is only one dsHead per term and no nested dsHeads *)
			Scan[
				If[	!MatchQ[#, a_. dsHead[b_]/; (FreeQ[{a,b}, dsHead] && !FreeQ[b,DiracGamma])],
					Message[DiracTrace::failmsg, "Irregular trace structure in", InputForm[#]];
					Print[#];
					Abort[]
			]&, dsPart+dsHead[DiracGamma] ];
		];

		(* 	Now it is guaranteed that dsPart is of the form a*dsHead[x]+b*dsHead[y]+c*dsHead[z]+...
			So it is safe to extract all the dsHead objects and handle them separately	*)
		diracObjects = Cases[dsPart+null1+null2, dsHead[_], Infinity]//Union;

		time=AbsoluteTime[];
		FCPrint[1, "DiracTrace. Applying diractraceev2.", FCDoControl->diTrVerbose];

		diracObjectsEval = Map[diractraceev2[#, Flatten[Join[{op}, FilterRules[Options[DiracTrace], Except[{op}]]]]]&,
			(diracObjects/.dsHead->Identity)];

		repRule = MapThread[Rule[#1,#2]&,{diracObjects,diracObjectsEval}];
		FCPrint[3,"DiracTrace: repRule: ",repRule , FCDoControl->diTrVerbose];

		tr3 = (unitMatrixTrace freePart) + ( dsPart/.repRule);

		(* If the result should contain Mandelstam variables *)
		If[ Length[OptionValue[Mandelstam]] > 0,
			tr3 = TrickMandelstam @@ Prepend[{OptionValue[Mandelstam]}, tr3]
		];

		If [OptionValue[FeynCalcExternal],
			diTres = FCE[tr3],
			diTres = tr3
		];

		FCPrint[1, "DiracTrace: Leaving.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrace: Leaving with", diTres, FCDoControl->diTrVerbose];

		If[ !FreeQ[diTres,DiracGamma],
			Message[DiracTrace::rem];
			Abort[]
		];

		diTres
	]/; OptionValue[DiracTraceEvaluate] && FreeQ[x,SUNT]

diractraceev2[nnx_,opts:OptionsPattern[]] :=
	Block[ {diractrjj, diractrlnx, diractrres, diractrny = 0, diractrfact, nx,
		diractrcoll, schoutenopt, diractrnyjj,
		dtmp,dWrap,dtWrap,wrapRule,prepSpur,time,time2,contract},

		wrapRule = {dWrap[5]->0, dWrap[6]->1/2, dWrap[7]->1/2, dWrap[LorentzIndex[_,_:4],___]->0,
					dWrap[_. Momentum[_,_:4]+_:0,___]->0};

		diractrfact = OptionValue[DiracTrace,{opts},Factoring];
		diractrcoll = OptionValue[DiracTrace,{opts},PairCollect];
		schoutenopt = OptionValue[DiracTrace,{opts},Schouten];
		contract  	= OptionValue[DiracTrace,{opts},Contract];
		west		= OptionValue[DiracTrace,{opts},West];

		If[ diractrfact === Automatic,
			diractrfact = Function[x, If[ LeafCount[x] <  5000,
										Factor[x],
										x
									]];
		];

		FCPrint[1,"DiracTrace: diractraceev2: Entering", FCDoControl->diTrVerbose];
		FCPrint[2,"DiracTrace: diractraceev2: Entering with: ",nnx, FCDoControl->diTrVerbose];

		nx = nnx;
		time=AbsoluteTime[];
		FCPrint[1,"DiracTrace: diractraceev2: Applying DiracTrick.", FCDoControl->diTrVerbose];
		diractrny = DiracTrick[nx, FCI -> True];
		FCPrint[1,"DiracTrace: diractraceev2: DiracTrick done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: diractraceev2: After DiracTrick: ",diractrny, FCDoControl->diTrVerbose];


		time=AbsoluteTime[];
		diractrny = Expand2[ExpandScalarProduct[diractrny], Pair];

		If[ !FreeQ[diractrny, DiracGamma],
			(* If the output of DiracSimplify still contains Dirac matrices, apply DotSimplify and try
			to evaluate the traces of Dirac matric chains via spursav *)
			(*	We need to consider standalone Dirac matrices separately
											With the following all of them will  be wrapped inside
											dWrap or dtWrap *)
			time2=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diractraceev2: Calculating the trace.", FCDoControl->diTrVerbose];

			diractrny = DotSimplify[diractrny, Expanding -> True];
			diractrny = DiracTrick[diractrny, FCI -> True];


			FCPrint[3,"DiracTrace: diractraceev2: After DotSimpify: ",diractrny, FCDoControl->diTrVerbose];


			diractrny = diractrny /.  {DiracGamma -> dWrap,DiracGammaT -> dtWrap} /.
				DOT -> prepSpur;
			diractrny = diractrny /. prepSpur[zzz__] :> spursav@@({zzz} /. {dWrap -> DiracGamma,dtWrap->DiracGammaT});

			FCPrint[1,"DiracTrace: diractraceev2: Done calculating the trace, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose];


			If[ OptionValue[DiracTrace,{opts},Expand],
				time2=AbsoluteTime[];
				FCPrint[1,"DiracTrace: diractraceev2: Expanding the result w.r.t Pairs", FCDoControl->diTrVerbose];
				diractrny=Expand2[ExpandScalarProduct[diractrny],Pair];
				FCPrint[1,"DiracTrace: diractraceev2: Done expanding the result, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose]
			];

			(* The trace of any standalone Dirac matrix is zero,
			g^6 and g^7 are of course special *)
			diractrny = diractrny/. wrapRule;
			FCPrint[3,"DiracTrace: diractraceev2: diractrny", diractrny, FCDoControl->diTrVerbose];


			If[ !FreeQ2[diractrny,{dWrap,dtWrap,spur}],
				Message[DiracTrace::rem];
				Abort[]
			]
		];

		FCPrint[1,"DiracTrace: diractraceev2: Main loop finished, timing:",N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];

		(* After spur there should no Dirac matrices left, by definition! *)
		If[ !FreeQ[diractrny,DiracGamma],
			Message[DiracTrace::rem];
			Abort[]
		];

		FCPrint[2,"DiracTrace: diractraceev2: Contracting Lorentz indices. Time used: ", TimeUsed[], FCDoControl->diTrVerbose];

		(* If the output of the second DiracSimplify contains Lorentz indices, try
		to contract them *)
		If[ (contract===True || (NumberQ[contract] && LeafCount[diractrny] < contract)) && !FreeQ[diractrny, LorentzIndex],
			time=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diractraceev2: Contracting Lorentz indices. ", FCDoControl->diTrVerbose];
			diractrny=Contract[diractrny];
			FCPrint[1,"DiracTrace: diractraceev2: Contract done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose]
		];


		(* Special expansion for expressions that contain Levi-Civita tensors*)
		If[ !FreeQ[diractrny, Eps],
			time=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diractraceev2: Treating Eps tensors.", FCDoControl->diTrVerbose];
			diractrny = EpsEvaluate[diractrny]//Expand;
			diractrny = Contract[ diractrny, EpsContract -> OptionValue[DiracTrace,{opts},EpsContract],
								Schouten->schoutenopt, Expanding -> False ];
			FCPrint[1,"DiracTrace: diractraceev2: Done with Eps tensors, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose]
		];

		(* Factor the result, if requested *)
		(* This is where we put back the prefactor of 4! *)
		time=AbsoluteTime[];
		FCPrint[1,"DiracTrace: diractraceev2: Factoring the result.", FCDoControl->diTrVerbose];
		If[ diractrfact===True,
			diractrres = Factor2[unitMatrixTrace diractrny],
			If[ diractrfact===False,
				diractrres = unitMatrixTrace diractrny,
				diractrres = diractrfact[unitMatrixTrace diractrny]
			]
		];
		FCPrint[1,"DiracTrace: diractraceev2: Factoring done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];


		time=AbsoluteTime[];
		FCPrint[2,"DiracTrace: diractraceev2: Applying TrickMandelstam.",FCDoControl->diTrVerbose];

		diractrpc[x__] :=
			Plus[x]/;FreeQ[{x},Pair];
		(* If the result should be collected w.r.t Pairs *)
		If[ diractrcoll===True,
			time=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diractraceev2: Collecting the result w.r.t Pairs.", FCDoControl->diTrVerbose];
			diractrpc[x__] :=
				Collect2[ Plus[x],Pair ,Factoring -> False];
			diractrres = diractrres/. Plus -> diractrpc;
			FCPrint[1,"DiracTrace: diractraceev2: Collecting done, timing", N[AbsoluteTime[] - time, 4],  FCDoControl->diTrVerbose];


		];

		FCPrint[1,"DiracTrace: diractraceev2: Leaving.", FCDoControl->diTrVerbose];

		diractrres
	]/; !FreeQ2[nnx,{DOT,DiracGamma}];


spursav[x__DiracGamma] :=
	spur[x];
(*Added 28/2-2001 by F.Orellana. Fix to bug reported by A.Kyrielei*)

spursav[x : ((DiracGamma[__] | HoldPattern[Plus[__DiracGamma]]) ..)] :=
	spur[x];



(*
	Some assumptions about objects that can appear in spur:
	1) All of them are Dirac matrices, i.e. no other non-commutative objects.
	2) g^5, g^6 or g^7 is always on the end of the chain.
*)




spurNDR[x___]:=spur[x];





(* ------------------------------------------------- *)

spur[0 ..] :=
	0;

spur[] =
	1;

spur[DiracGamma[5|6|7]] =
	0;

(* 	We assume that a chiral trace with an odd number of g^i or less than 4 g^i is zero in any scheme	*)
spur[x__DiracGamma,DiracGamma[5|6|7]] :=
	0/; OddQ[Length[{x}]];

spur[x__DiracGamma,DiracGamma[5]] :=
	0/; Length[{x}] < 4;

spur[x__DiracGamma] :=
	0/; OddQ[Length[{x}]] && FreeQ2[x,{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];

spur[x_DiracGamma, y_DiracGamma] :=
	Pair[x[[1]],y[[1]]]/; FreeQ2[{x,y},{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];

spur[i_DiracGamma, j_DiracGamma, k_DiracGamma, l_DiracGamma] :=
	(	Pair[i[[1]], l[[1]]] Pair[j[[1]],k[[1]]] -
		Pair[i[[1]], k[[1]]] Pair[j[[1]],l[[1]]] +
		Pair[i[[1]], j[[1]]] Pair[k[[1]],l[[1]]])/; FreeQ2[{x,y,r,s},{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];

(* calculation of traces (recursively) --  up to a factor of 4 *)
(*	Trace of g^mu g^nu g^rho g^si g^5	*)


(* 	All Dirac matrices are 4-dim. Simple case. *)
spur[x_DiracGamma,y_DiracGamma,r_DiracGamma,z_DiracGamma, DiracGamma[5]] :=
	(EpsEvaluate[$LeviCivitaSign I Eps[x[[1]],y[[1]],r[[1]],z[[1]]]])/;
		FCGetDimensions[{x,y,r,z}]==={4};

(* 	For all other cases special treatment is needed... *)
spur[x_DiracGamma,y_DiracGamma,r_DiracGamma,z_DiracGamma, DiracGamma[5]] :=
	Block[{dims,tmp},
		dims=FCGetDimensions[{x,y,r,z}];
		Which[

			(* D-dims, BMHV -> gets converted to 4 Dims*)
			MatchQ[dims, {_Symbol}] && !$Larin && $BreitMaison,
				tmp = Eps[x[[1]],y[[1]],r[[1]],z[[1]]],
			(* D-dims, Larin -> remains in Dims*)
			MatchQ[dims, {_Symbol}] && $Larin && !$BreitMaison,
				tmp = Eps[x[[1]],y[[1]],r[[1]],z[[1]],Dimension->dims[[1]]],
			(* 4-dims, D-dims and D-4 dims mixtures, BMHV -> gets converted to 4 Dims*)
			(MatchQ[dims, {4,_Symbol}] || MatchQ[dims, {4,_Symbol-4}] || MatchQ[dims, {s_Symbol-4,s_Symbol}] || MatchQ[dims, {4, s_Symbol-4,s_Symbol}])	&& !$Larin && $BreitMaison,
				tmp = Eps[x[[1]],y[[1]],r[[1]],z[[1]]],
			(* any other combination is most likely an error*)
			True,
			Message[DiracTrace::fail, FullForm[{x,y,r,z,DiracGamma[5]}]];
			Abort[]
		];
		EpsEvaluate[$LeviCivitaSign I tmp]
	]/;FCGetDimensions[{x,y,r,z}]=!={4};

spur[x__DiracGamma,DiracGamma[6]] :=
	(1/2 spur[x] + 1/2 spur[x,DiracGamma[5]])/; EvenQ[Length[{x}]];

spur[x__DiracGamma,DiracGamma[7]] :=
	(1/2 spur[x] - 1/2 spur[x,DiracGamma[5]])/; EvenQ[Length[{x}]];

(*g^6 or g^7 not in the correct position...*)
spur[x__] :=
	(DiracTrace@@(gamma67back[ {x} ]))/; !FreeQ2[{x},{DiracGamma[6],DiracGamma[7]}];

gc[x_] :=
	x/.DiracGamma->gach;
gach[ex_,___] :=
	ex /; Length[ex]>0;
gach[n_Integer] =
	DiracGamma[n];
(* This function handles general  Dirac traces *)

spur[y__] :=
	Block[ {spx,le = Length[{y}],tempres,i,spurjj,tempr,
		temp2 = 0, fi,spt, resp,dirsign,time,fi1,fi2,fi3,drsi},
		spx = ( {y}//DiracGammaExpand )/.DiracGamma->gach;
		temp2 = Hold[spur][spx];
		time = AbsoluteTime[];
		FCPrint[1, "DiracTrace: spur: Entering.", FCDoControl->diTrVerbose];
		FCPrint[2, "DiracTrace: spur: Entering with ", spx, FCDoControl->diTrVerbose];

		resp =
		Which[
			(*Trace of an odd number of Dirac matrices without gamma^5 *)
			OddQ[le] && FreeQ2[FRH[spx], {DiracGamma[5],DiracGamma[6],DiracGamma[7]}],
				0,
			(* For traces with an even number of Dirac matrices without gamma^5
			use the trace reduction equation from Veltman's Gammatrica (p.255) plus
			a tweaked version of Thomas Hahn's Trace4 with some memoization magic *)
			FreeQ[spx,DiracGamma[5]],
				traceNo5Wrap@@spx,
			(* Here we handle traces with of type g^i1 .... g^in g^5 with n>=6*)
			FreeQ[Drop[spx,-1], DiracGamma[5]] && Length[spx] > 6,
				FCPrint[2,"Computing the chiral trace ", spx, FCDoControl->diTrVerbose];
				Which[
					(* NDR *)
					!$Larin && !$BreitMaison,
						If[ MatchQ[SelectFree[spx,{(LorentzIndex | Momentum)[_],DiracGamma[5]}], {} ],
							(* If the trace is purely four dimensional, NDR is ok here. *)
							(*Apply the standard anomalous trace formula (c.f. Eq 2.18 of R. Mertig, M. Boehm,
							A. Denner. Comp. Phys. Commun., 64 (1991)) *)
							FCPrint[3,"The chiral trace", spx, "is computed using the standard recursion formula in NDR", FCDoControl->diTrVerbose];
							trace5Wrap@@(spx//.DiracGamma[5]->5),
							(* Otherwise abort the computation, since NDR cannot handle anomalous traces without an
							additional prescription*)
							Message[DiracTrace::ndranomaly, InputForm[DOT[y]]];
							Abort[];
						],
					(* Larin *)
					$Larin && !$BreitMaison,
						FCPrint[3,"The chiral trace", spx, "is computed in Larin's scheme", FCDoControl->diTrVerbose];
						{fi1, fi2, fi3} = LorentzIndex[#,D]& /@ Unique[{"a","b","c"}];
						drsi = $LeviCivitaSign/(TraceOfOne/.Options[DiracTrace]);
						(*drsi is usually -1/4 *)
						temp2 = spx /. {a___, lomo_[mUU_,di___], DiracGamma[5]} :>
						TR[ drsi I/6 Eps[lomo[mUU,di], fi1, fi2, fi3] *
						DOT @@ Map[DiracGamma[#,D]&, {a,fi1,fi2,fi3}], EpsContract->True];
						temp2/.spt->spursavg/.spursavg->spug,
					(* BMHV, standard (slow!) trace formula *)
					!$Larin && $BreitMaison && !west,
						FCPrint[3,"The chiral trace", spx, "is computed in the BMHV scheme using the slow formula", FCDoControl->diTrVerbose];
						fi = Table[LorentzIndex[ Unique[] ],{spurjj,1,4}];
						drsi = $LeviCivitaSign/(TraceOfOne/.Options[DiracTrace]);
						(tmp @@ ({y}/.DiracGamma[5]->
						(drsi I/24 (DOT[DiracGamma[fi[[1]]],DiracGamma[fi[[2]]],
						DiracGamma[fi[[3]]],DiracGamma[fi[[4]]]]) (Eps@@fi))))/. tmp[arg__] :> DiracTrace[arg,DiracTraceEvaluate->True],
					(* BMHV West's trace formula *)
					!$Larin && $BreitMaison && west,
						FCPrint[3,"The chiral trace", spx, "is computed in the BMHV scheme using West's formula", FCDoControl->diTrVerbose];
						temp2 = Expand[2/(Length[spx]-5) Sum[(-1)^(i+j+1) *
						FCUseCache[ExpandScalarProduct,{spx[[i]],spx[[j]]},{}] spt@@Delete[spx,{{j},{i}}],
							{i,2,Length[spx]-1},{j,1,i-1}]];
						(*temp2/.spt->spursavg/.spursavg->spug,*)
						temp2 = temp2/.spt-> spur;
						Print[temp2];
						temp2,
						(* Any other combination of $Larin, $BreitMaison doesn't describe
						a valid scheme *)
					True,
						Message[DiracTrace::ilsch, $BreitMaison,$Larin]
				],
		True,
		Message[DiracTrace::fail, FullForm[spx]]
		];


		FCPrint[1,"DiracTrace: spur: Finished, timing:",N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: spur: Leaving with:",resp, FCDoControl->diTrVerbose];
		FCPrint[1,"DiracTrace: spur: Leaving.", FCDoControl->diTrVerbose];

		resp
	]/; Length[{y}]>5;


spursavg[x___, LorentzIndex[a_, dim_ : 4], LorentzIndex[a_, dim_ : 4], y___] :=
	(dim spursavg[x, y]) /. spursavg -> spug;

spug[x___] :=
	spursav@@(Map[diracga, {x}] /. diracga -> DiracGamma);

diracga[DiracGamma[h_Integer]] :=
	DiracGamma[h];

diracga[LorentzIndex[mu_, dii_]] :=
	diracga[LorentzIndex[mu,dii],dii];

diracga[Momentum[p_, dii_]] :=
	diracga[Momentum[p, dii],dii];

fastExpand[xx_] :=
	Replace[xx, p_. Times[a__, x_Plus] :> Distribute[p a*x, Plus], 1];

(*	traceNo5Wrap is a higher level function that handles the computation of traces without gamma 5,
	all indices different.  The trick here 	is that as soon as we compute a trace for a given number of Dirac matrices,
	we define it is a function (traceNo5fun) so that the result can be retrieved very fast. Combined with the the fast expansion
	using fastExpand this provides a rather quick way to obtain Dirac traces. The bottlenecks here are the amount of RAM required
	for caching and the general slowness of Mathematica on very large expressions. Traces with up to 14 Dirac matrices should be fine,
	after that it becomes too slow *)

traceNo5Wrap[SI1_, SI2__] :=
	Block[{res, repRule, tab, set, SI, args, setDel, tmpRes, finalRes},

		tab = Table[ ToExpression["MySI" <> ToString[i]], {i, 1, Length[{SI1, SI2}]}];
		finalRes = traceNo5Fun @@ {SI1, SI2};

		If[Head[finalRes] === traceNo5Fun,
			(* The trace needs to be computed *)
			tmpRes = traceNo5 @@ tab;
			If[	($MemoryAvailable - MemoryInUse[]/1000000.) >1. ,
				(* If there is enough memory, we save the computed result as a function *)
				args = Sequence @@ (Pattern[#, _] & /@ tab);
				setDel[traceNo5Fun[args], fastExpand[tmpRes]] /. setDel -> SetDelayed;
				res = traceNo5Fun @@ {SI1, SI2},
				(* No memoization if we have not enough memory *)
				res = tmpRes /. Thread[Rule[tab, {SI1,SI2}]]

			],
			(* The trace has already been computed *)
			res = finalRes
		];

		res
	];

traceNo5Wrap[] =
	1;

(* 	traceNo5 is the lower level function that computes only indices of type S[1],S[2],... and
	remembers its values. It's based on Thomas Hahn's famous Trace4  function *)
traceNo5[SI1_, SI2__] :=
	Block[{head, s = -1, res},
		res = Plus @@ MapIndexed[((s = -s) Pair[SI1, #1] Drop[head[SI2], #2]) &, {SI2}];
		res = res /. head -> traceNo5Wrap;
		res
	];

(* 	trace5Wrap computes a 4-dimensional trace of Dirac matrices with one gamma 5 using
	similar tricks as traceNo5Wrap. *)
trace5Wrap[SI1__, 5] :=
	Block[{res, repRule, tab, set, args, setDel, tmpRes, realRes},
		tab = Table[ToExpression["MySI" <> ToString[i]], {i, 1, Length[{SI1}]}];

		realRes = trace5Fun @@ {SI1, 5};

		If[Head[realRes] === trace5Fun,
			(* The trace needs to be computed *)
			tmpRes = trace5 @@ (Join[tab, {5}]);
			If[	($MemoryAvailable - MemoryInUse[]/1000000.) >1. ,
				(* If there is enough memory, we save the computed result as a function *)
				args = Sequence @@ Join[(Pattern[#, _] & /@ tab), {5}];
				setDel[trace5Fun[args], fastExpand[tmpRes]] /. setDel -> SetDelayed;
				res = trace5Fun @@ {SI1, 5},
				(* No memoization if we have not enough memory *)
				res = tmpRes /. Thread[Rule[tab, {SI1}]]

			],
			(* The trace has already been computed *)
			res = realRes
		];
		res
	];

trace5[SI1_, SI2__, mu_, nu_, rho_, 5] :=
	Pair[mu, nu] trace5[SI1, SI2, rho, 5] -
	Pair[mu, rho] trace5[SI1, SI2, nu, 5] +
	Pair[nu, rho] trace5[SI1, SI2, mu, 5] -
	$LeviCivitaSign I traceEpsNo5[mu, nu, rho, SI1, SI2];


(*
trace5[mu_, nu_, rho_, SI1_, SI2__, 5] :=
	Pair[mu, nu] trace5[rho, SI1, SI2, 5] -
	Pair[mu, rho] trace5[nu, SI1, SI2, 5] +
	Pair[nu, rho] trace5[mu, SI1, SI2, 5] +
	epsTensorSign I traceEpsNo5[mu, nu, rho, SI1, SI2]
*)

trace5[a_, b_, c_, d_, 5]:=
	$LeviCivitaSign I Eps[a, b, c, d];

traceEpsNo5[mu_, nu_, rho_, SI2__] :=
	Block[{head, s = -1, res},
		res = Plus @@ MapIndexed[((s = -s) Eps[mu, nu, rho, #1] Drop[head[SI2], #2]) &, {SI2}];
		res = res /. head -> traceNo5Wrap;
		res
	];


(*
(* Not needed anymore *)
diractraceevsimple[x_, OptionsPattern[]] :=
	unitMatrixTrace x/; FreeQ[x, DiracGamma];

(* Not needed anymore *)
diractraceevsimple[y_ DOT[x_,z__], opts:OptionsPattern[]] :=
	(y diractraceevsimple[DOT[x,z], opts])/; FreeQ[y, DiracGamma];

(* Not needed anymore *)
diractraceevsimple[x_Plus , opts:OptionsPattern[]] :=
	Map[diractraceevsimple[#,{opts}]&, x];
*)
(*
diractraceevsimple[DOT[x___], opts:OptionsPattern[]] :=
	(If[ FreeQ[#,LorentzIndex],
		#,
		Expand2[#/.Pair->PairContract/.PairContract->Pair,Pair]
	]&[diractraceev[Sequence@@DOT[x],opts]])/;
	(MatchQ[List@@DOT[x], { DiracGamma[(LorentzIndex | Momentum)[_,_],_]..}] ||
	MatchQ[List@@DOT[x], { DiracGamma[(LorentzIndex | Momentum)[_]]..}] ||
	MatchQ[List@@DOT[x], { DiracGamma[(LorentzIndex | Momentum)[_,_],_]..,
		DiracGamma[5 | 6 | 7]} ] ||
	MatchQ[List@@DOT[x], { DiracGamma[(LorentzIndex | Momentum)[_]]..,
		DiracGamma[5 | 6 | 7]}]);


dirli[LorentzIndex[xx_, ___],___] :=
	xx;

diractraceev[DiracGamma[LorentzIndex[a1_,dii_],dii_],
			DiracGamma[LorentzIndex[a2_,dii_],dii_],
			DiracGamma[LorentzIndex[a3_,dii_],dii_],
			a4:DiracGamma[LorentzIndex[_,dii_],dii_]..,
			DiracGamma[LorentzIndex[a1_,dii_],dii_],
			DiracGamma[LorentzIndex[a2_,dii_],dii_],
			DiracGamma[LorentzIndex[a3_,dii_],dii_],
			a4:DiracGamma[LorentzIndex[_,dii_],dii_]..,
			OptionsPattern[]
			] :=
	unitMatrixTrace dcs[dii]@@Join[{a1,a2,a3}, {a4}/.DiracGamma->dirli,
	{a1,a2,a3}, {a4}/.DiracGamma->dirli];

dcs[dim_][x___] :=
	(dics[dim][x] /. dics->dc);

dc[_][] =
	1;

dics[_][] =
	1;

dics[dI_][a___, n_, n_, b___] :=
	dI dics[dI][a, b];

dics[dI_][a___, n_, z_, n_, b___ ] :=
	(2-dI) dics[dI][a, z, b];

dics[dI_][a___, n_, v_, w_, n_, b___] :=
	(dI-4) dics[dI][a, v,w, b] + 4 (dics[dI]@@({a, b}/. v -> w));

dics[dI_][a___, n_, v_, w_, z_, n_, b___] :=
	(4-dI) dics[dI][a, v,w,z, b] - 2 dics[dI][a, z,w,v,b];

dics[dI_][a___, n_, mu_, nu_, ro_,si_, n_, b___] :=
	(dI-4) dics[dI][a, mu,nu,ro,si, b] +
	2 dics[dI][a, ro,nu,mu,si,b] + 2 dics[dI][a, si,mu,nu,ro,b];

dics[dI_][a___, n_, mu_, nu_, ro_, si_, de_, n_, b___] :=
	(4-dI) * dics[dI][a, mu,nu,ro,si,de, b] - 2 dics[dI][a, mu,de,nu,ro,si, b] -
	2 dics[dI][a, mu,si,ro,nu,de, b] + 2 dics[dI][a, nu,ro,si,de,mu, b];

dicsav[dd_][x___] :=
	dics[dd][x];

dc[di_][a___, mu_, lim__, mu_, b___] :=
	Expand[
		Block[ {m = Length[{lim}], i, j},
			(-1)^m ( (di-2 m) dicss[di][a,lim,b] -
			4 Sum[(-1)^(j-i) *
			If[ {lim}[[j]] === {lim}[[i]],
				di (dicss[di] @@Join[{a}, Delete[{lim}, {{i},{j}}], {b}]),
				dicss[di] @@(Join[{a}, Delete[{lim}, {{i},{j}}], {b}]/.
				({lim}[[j]]) -> ({lim}[[i]]))
			],     {i,1,m-1}, {j,i+1,m}])
		] /. dicss -> dicsav//. dics -> dcs];
		*)
(* ****************************************************** *)
(*							(*conalldef*)
conall[ x_,opts:OptionsPattern[]] :=
	Contract[x, Expanding->True, EpsContract-> OptionValue[DiracTrace,{opts},EpsContract],
	Factoring->False ];

fr567[x__] :=
	FreeQ2[FixedPoint[ReleaseHold,{x}], {DiracGamma[5],DiracGamma[6],DiracGamma[7]}];

diractraceev[x_, opts:OptionsPattern[]] :=
	Block[ {trfa = 1, enx = x},
		If[ Head[x] === Times,
			trfa = Select[x, FreeQ2[#, {DiracGamma, LorentzIndex, Eps}]&];
			enx = x / trfa;
		];
		diractraceev2[conall[enx], opts] trfa
	];
*)


FCPrint[1,"DiracTrace.m loaded."];
End[]
