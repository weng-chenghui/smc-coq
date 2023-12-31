From mathcomp Require Import ssreflect eqtype ssrbool ssrnat seq tuple ssrfun fintype.
Require Import ssrZ ZArith_ext uniq_tac ssrnat_ext.


(* Because I'm not sure which vector lib I should use,
   and because of all time I tried and spent on debugging dependant types:

   https://stackoverflow.com/questions/42302300/which-vector-library-to-use-in-coq

   I think current a simple list is sufficient.
*)
Fixpoint zipWith {A B: Type} (fn : A -> A -> B) (l1 : list A) (l2 : list A) : list B :=
	match l1, l2 with
	| [::], _ => [::]
	| _, [::] => [::]
	| a1 :: tl1, a2 :: tl2 => fn a1 a2 :: (zipWith fn tl1 tl2)
	end.

Fixpoint nth_element {A : Type} (n : nat) (l : list A) : option A :=
	match n, l with
	| 0%nat, h :: _ => Some h
	| S n', _ :: tl => nth_element n' tl
	| _, _ => None
	end.

Definition dotproduct (la lb: list Z) : Z :=
	foldl (fun sum current => sum + current) 0 (zipWith (fun a b => a * b) la lb).

Definition add (la lb: list Z) : list Z :=
	zipWith (fun a b => a + b) la lb.

Definition add_mod2 (la lb: list Z) : list Z :=
	zipWith (fun a b => (a + b) mod 2) la lb.

Reserved Notation "la '`*' lb" (at level 40, format "'[' la  `*  lb ']'").
Notation "la '`*' lb" := (dotproduct la lb).

Reserved Notation "la '`+' lb" (at level 50, format "'[' la  `+  lb ']'").
Notation "la '`+' lb" := (add la lb).

Reserved Notation "la '`+_2' lb" (at level 50, format "'[' la  `+_2  lb ']'").
Notation "la '`+_2' lb" := (add_mod2 la lb).

Eval compute in (([::1;2] `+ [::1;2;3]) `* [::-1;-2]).

(* ---- SMC Scalar-product ---- *)

(* Alice: get X'a and pass it to Bob *)
Definition scalar_product_alice_step1 (Xa Ra: list Z): list Z :=
	Xa `+ Ra.
 
(* Alice: get ya in the SMC scalar-product. *)
Definition scalar_product_alice_fin (X'b Ra: list Z) (ra t: Z): Z :=
	(t - (Ra `* X'b) + ra).

(* Bob: get X'b and pass it to Alice *)
Definition scalar_prduct_bob_step1 (Xb Rb: list Z): list Z :=
	Xb `+ Rb.

(* Bob: receive X'a from Alice and get `t` then pass it to Alice *)
Definition scalar_prduct_bob_step2 (Xb X'a: list Z) (rb yb: Z): Z :=
	(Xb `* X'a) + rb - yb.

Definition scalar_product_bob_step_fin (yb: Z): Z :=
	yb.

(* Because `rb` is not generated from RNG:
   rb =  Ra . Rb - ra
*)
Definition scalar_product_commidity_rb (Ra Rb: list Z) (ra: Z): Z :=
	(Ra `* Rb) - ra.

Definition scalar_product (Ra Rb: list Z) (ra rb yb: Z) (Xa Xb: list Z): (Z * Z) :=
	let X'a := scalar_product_alice_step1 Xa Ra in
	let X'b := scalar_prduct_bob_step1 Xb Rb in
	let t := scalar_prduct_bob_step2 Xb X'a rb yb in
	let ya := scalar_product_alice_fin X'b Ra ra t in
	(scalar_product_alice_fin X'b Ra ra t, scalar_product_bob_step_fin yb).

Definition demo_Alice3_Bob2 : (Z * Z) :=
	let Ra := [:: 9 ] in
	let Rb := [:: 8 ] in
	let ra := 13 in
	let rb := scalar_product_commidity_rb Ra Rb ra in	(* rb =  Ra . Rb - ra *)
	let Xa := [:: 3 ] in
	let Xb := [:: 2 ] in
	let yb := 66 in
	scalar_product Ra Rb ra rb yb Xa Xb.

(* Scalar-product: (Xa1....Xan, Xb1...Xbn) |-> (ya, yb), where

	ya + yb = Xa * Xb

*)

Lemma dot_productC (aa bb : list Z) : aa `* bb = bb `* aa.
Admitted.

Lemma dot_productDr (aa bb cc : list Z) : aa `* (bb `+ cc) = aa `* bb + aa `* cc.
Admitted.

Definition SMC := list Z -> list Z -> (Z * Z).

Definition is_scalar_product (sp: SMC) :=
	forall(Xa Xb: list Z),
	let (ya, yb') := sp Xa Xb in
	ya + yb' = Xa `* Xb.

Lemma scalar_product_correct (Ra Rb : list Z) (ra yb : Z) :
  let rb := scalar_product_commidity_rb Ra Rb ra in
  is_scalar_product (scalar_product Ra Rb ra rb yb).
Proof.
move=>/=Xa Xb/=.
rewrite /scalar_product_alice_fin.
rewrite /scalar_prduct_bob_step2.
rewrite /scalar_product_alice_step1.
rewrite /scalar_prduct_bob_step1.
rewrite /scalar_product_bob_step_fin.
rewrite /scalar_product_commidity_rb.
rewrite !dot_productDr.
rewrite (dot_productC Xb Xa).
rewrite (dot_productC Xb Ra).
ring.
Qed.

Lemma demo_smc_scalar_product: fst demo_Alice3_Bob2 + snd demo_Alice3_Bob2 = 3 * 2.
Proof.
	compute.
	done.
Qed.



Definition preset_sp (Ra Rb: list Z) (ra yb: Z): SMC :=
	scalar_product Ra Rb ra (scalar_product_commidity_rb Ra Rb ra) yb. 

(* Before we can have a Monad,
   use curried version to store the commodity, so use it like:

   (commodity Ra Rb ra yb) Xa Xb
*)
Definition commodity (Ra Rb: list Z) (ra yb: Z): SMC :=
	let rb := scalar_product_commidity_rb Ra Rb ra in
	scalar_product Ra Rb ra rb yb.

(* In most of protocols, there are more than one scalar-product,
   therefore more than one commodity is necessary.

   (A temporary workaround before we have RNG.)
   ()
*)
Fixpoint commodities (Ras Rbs: list (list Z)) (ras ybs: list Z): list SMC :=
	match Ras, Rbs, ras, ybs with
	| Ra :: tlRas, Rb :: tlRbs, ra :: tlras, yb :: tlybs =>
		commodity Ra Rb ra yb :: commodities tlRas tlRbs tlras tlybs
	| _, _, _, _ => [::]
	end.

(* Note before implementation of other protocols:

   1. Scalar-product's input is vector, but for other protocols,
      the input could be one single integer or other things,
	  it depends on the protocol design.

   2. How other protocols use scalar-product,
      and how they prepare the vector inputs to scalar-products,
	  depend on each protocol's design.

   3. The basic format of other protocol is that inputs held by Alice and Bob,
      no matter they are vectors or integers, in the form:

	      (InputA, InputB) |-> (OutputA, OutputB)

	  This law must keep:

	      InputA (non-SMC op) InputB = OutputA + OutputB
	  
	  So that in the protocol paper,

	      'Scalar-product-based Secure Two-party Computation',

	  The 'Input' is always described 'shared',
	  because Alice holds half of the Input, and Bob holds another half.
	  While this process in non-SMC will be:

	      Input -> Output

	  Now in the SMC world, one Input of unary operation becomes InputA and InputB.
	  In binary operation it becomes Input1A, Input1B, Input2A, Input2B, like in
	  the less_than protocol:

	      (Xa, Xb), (Ya, Yb) |-> (Za, Zb)
	
	  Where:
	  	
	      Za + Zb = {1, if (Xa + Xb) < (Ya + Yb); otherwise, 0 }

	  In this case, Alice holds Xa and Ya, while Bob holds Xb and Yb.
*)

(* ---- SMC Zn-to-Z2 ---- *)

(* Sidenote: maybe use int 32 from Seplog for this protocol. *)

(* Zn-to-Z2:

   (Alice: Xa, Bob: Xb) |-> (ya0...yak), (yb0...ybk), such that:
   Xa + Xb = X = (yk yk-1 ... y1 y0)2, where yi = (yia + yib) mod 2
*)

Definition zn_to_z2_step2_1 (sp: SMC) (ci xi: (Z * Z)) : (Z * Z) :=
	sp [:: ci.1; xi.1; xi.1] [:: xi.2; ci.2; xi.2].

(* Step 2 for two party. *)
Definition zn_to_z2_step2_2 (ti: Z * Z) (ci xi xi' : Z * Z) :
  (Z * Z) * (Z * Z) :=
	let cai' := (ci.1 * xi.1 + ti.1) mod 2 in
	let cbi' := (ci.2 * xi.2 + ti.2) mod 2 in
	let yai' := (xi'.1 + cai') mod 2 in
	let ybi' := (xi'.2 + cbi') mod 2 in
	((cai', cbi'), (yai', ybi')).

(* Shows it is correct if the `sp` fed to the step_2_1 is a SMC scalar-product. *)
(* Because SMC scalar-product its correctness also relies on all parameters from Ra to yb,
   parameters for both scalar_product and zn_to_z2_step2_1 are all listed.
*)
Lemma zn_to_z2_step2_1_correct (sp: SMC) (ci xi: Z * Z) :
	is_scalar_product sp ->
	let alice_input := [:: ci.1; xi.1; xi.1] in
	let bob_input := [:: xi.2; ci.2; xi.2] in
	let (tai, tbi) := zn_to_z2_step2_1 sp ci xi in
	tai + tbi = alice_input `* bob_input .
Proof.
apply.
Qed.


(* Note: xas and xbs are bit vector, so Z elements inside are only 1 or 0, from high to low bits*)
Definition zn_to_z2_int4 (sps: 4.-tuple SMC) (xas xbs: 4.-tuple Z): (4.-tuple Z * 4.-tuple Z) :=
	let x0 := ([tnth xas 0], [tnth xas 0]) in
	let x1 := ([tnth xas 1], [tnth xas 1]) in
	let x2 := ([tnth xas 2], [tnth xas 2]) in
	let x3 := ([tnth xas 3], [tnth xas 3]) in
	let s0 := [tnth sps 0] in
	let s1 := [tnth sps 1] in
	let s2 := [tnth sps 2] in
	let s3 := [tnth sps 3] in
	let c0 := (0,0) in
	let t0 := zn_to_z2_step2_1 s0 c0 x1 in
	let (c1, y1) := zn_to_z2_step2_2 t0 c0 x0 x1 in
	let t1 := zn_to_z2_step2_1 s1 c1 x2 in
	let (c2, y2) := zn_to_z2_step2_2 t1 c1 x1 x2 in
	let t2 := zn_to_z2_step2_1 s0 c2 x3 in
	let (c3, y3) := zn_to_z2_step2_2 t2 c2 x2 x1 in
	([tuple y3.1;y2.1;y1.1;x0.1], [tuple y3.2;y2.2;y1.2;x0.2]).


Definition to_dec_int4 (x: (4.-tuple Z)) : Z :=
	1 * [tnth x 0] + 2 * [tnth x 1] + 4 * [tnth x 2] + 8 * [tnth x 3].

Lemma zn_to_z2_int4_correct (sps: 4.-tuple SMC) (xas xbs: 4.-tuple Z):
	is_scalar_product [tnth sps 0] ->
	is_scalar_product [tnth sps 1] ->
	is_scalar_product [tnth sps 2] ->
	is_scalar_product [tnth sps 3] ->
	let x0 := ([tnth xas 0], [tnth xbs 0]) in
	let x1 := ([tnth xas 1], [tnth xbs 1]) in
	let x2 := ([tnth xas 2], [tnth xbs 2]) in
	let x3 := ([tnth xas 3], [tnth xbs 3]) in
	let (yas, ybs) := zn_to_z2_int4 sps xas xbs in
	(to_dec_int4 [tuple x3.1; x2.1; x1.1; x0.1]) + (to_dec_int4 [tuple x3.2; x2.2; x1.2; x0.2]) =
	(to_dec_int4 yas) + (to_dec_int4 ybs).
Proof.
move=>/=s1 s2 s3 s4/=.
Abort.
	

Definition zn_to_z2_folder (acc: Z * Z * list (Z * Z)) (curr: (SMC * ((Z * Z) * (Z * Z)))): Z * Z * list(Z * Z) :=
	let '(sp, ((xa, xa'), (xb, xb'))) := curr in
	let '(ca, cb, ys) := acc in 
	match head (0, 0) ys with (* get previous ca, cb and use them to calculate the new result, and push the new result to the acc list*)
	| (ya, yb) => 
		let '(cs, yab) := 
			zn_to_z2_step2_2 (zn_to_z2_step2_1 sp (ca, cb) (xa, xb)) (ca, cb) (xa, xb) (xa', xb')
		in (cs, yab :: ys)
	end.

(*
(x1,x2) 􏰀→ ((y10,...,y1k),(y20,...,y2k)), such that
(ykyk−1···y1y0)2 =x1+x2

( ya_(k-1)....ya_0 
  yb_(k-1)....yb_0
)

=
(y_k-1...y0)2 = (xa + xb)2

*)


(*
    xa_n, xb_n: the rest bits of input x hasn't been used in iterations.
	ys: a list of pairs contain all computated bits.
	ca_, cb_: from the paper step 2.b, y_i+1 = x_i+1 + c_i+1, so
	          the correct ca and cb should be implied from the latest (ya_i - xa_i) and (yb_i - xb_i) .

	Therefore, for each iteration by the zn_to_z2_folder, the correctness of `acc` means
	keeping the loop invariants listed here, from the first init acc of the 0th iteration,
	to the final acc of the (k-1)th iteration.
*)
Definition acc_correct (xas xbs: list Z) (acc: Z * Z * list (Z * Z)) :=
	let '(ca, cb, ys) := acc in
	let xa_n := drop (size xas - size ys) xas in
	let xb_n := drop (size xbs - size ys) xbs in
	let xa_nth := head 0 xa_n in
	let xb_nth := head 0 xb_n in
	let yas := unzip1 ys in
	let ybs := unzip2 ys in
	let head_y := head (0, 0) ys in
	let ca_ := head_y.1 - xa_nth in
	let cb_ := head_y.2 - xb_nth in
	yas `+ ybs = xa_n `+ xb_n /\	(* Correctness 1: def from the paper: [ ya_i + yb_i ... ya_0 + yb_0 ]_2 = (x_a + x_b)_2 -- SMC op result = non-SMC op result. *)
	ca_ = ca /\ cb_ = cb /\			(* Correctness 2: from step 2.b, the `c_i+1` that derived from `y_i+1` and `x_i+1`, should be equal to `c` we just folded in `acc` *)
	(0 < size ys <= size xas)%nat /\ (size xas = size xbs).	(* Other basic assumptions. *)

Lemma zn_to_z2_folder_correct acc curr (xas xbs: list Z):
	let acc' := zn_to_z2_folder acc curr in
	(* Here we can prove carry bits are correct because we now have the ith and (i+1)th step.
	   While in the `zn_to_z2_step2_1_correct` Lemma, there is no step i and i+1 at the same time,
	   so we cannot prove them there.
	*)
	(* We prove the folder is correct by induction, with an extra premises:

	   1. (premises) If the SMC operation in curr is a SMC scalar_product (which has been proved correct),

	   2. And by the hypothesis that zn_to_z2_folder_correct holds at ith step == its result acc is correct
	   
	   3. This should implies that the (i+1)th step is also correct.

	   Then we show that zn_to_z2_folder is correct for all inputs during all iterations.
	*)
	is_scalar_product curr.1 -> acc_correct xas xbs acc -> acc_correct xas xbs acc'.
Proof.
(* Spliting and moving all parameters to the proof context; for once we unwrap the acc_correct we will need them *)
case: acc=>[[ca cb] ys].
case: curr=>[smc [[xa xa'] [xb xb']]]. 
move=>/=t_from_zn_to_z2_step2_1_correct.
(* After moving the premises to the proof context, move acc_correct's hypothesis to the proof context *)
case=>[y_correct [ca_correct [cb_correct [y_not_empty xas_xbs_size_eq]]]].
(* We destruct ys to its head and tail _in the proof context_. *)
destruct ys as [|[y tail]]=>//.
(* Then we can unwrap the acc_correct, and do simplification. *)
rewrite /acc_correct/=.
(* We see zn_to_z2_step2_1, so immediately apply the zn_to_z2_step2_1_correct lemma with all parameters,
   and immediately apply it to the goal. *)
have:=zn_to_z2_step2_1_correct smc (ca, cb) (xa, xb) t_from_zn_to_z2_step2_1_correct.
destruct zn_to_z2_step2_1 as [tai tbi].
(* Simplify the proof context. Because now we have tai, tbi, ca, cb... and other things we want. *)
simpl in *.
move=>t_equation/=.
split.
2:{
	split.	(* Correctness 2 in acc_correct: the `c` is correct at each step *)
	1:{	(* ca is correct *) (* attempt: try to unwrap `tai` to ca, xa, cb, xb... so they can be simplified at once? *)
		apply ca_correct.
	}
	2:{	(* cb is correct *)
		split.
	}
}


Abort.


(* Note: cannot put x0a and x0b in lists because they need to be the init vars specified in params.
   Taking them from the xas and xbs will make two cases: if the lists are empty, cannot taking them.
   So if we don't want to be bothered by using dependant type just for guaranteeing that we have x0a and x0b,
   putting them in the param list seems easier.
*)
(* result: ([ya_k...ya_0], [yb_k...yb_0]) *)
Definition zn_to_z2 (sps: list SMC) (x0a x0b) (xas xbs: list Z): (list Z * list Z) :=
	(* What we need actually is: [:: (x2, x1); (x1, x0)] from high to low bits,
	   with overlapping element in each time we do foldering.
	   
	   So for example, `xas:6=1 1 0`, x0a: 0:

	   What we want:

	   [:: (x2=1, x1=1), (x1=1, x0=0)]

	   So we zip two lists, and because zip will drop extra part, we shift the first list by padding 0:

	       [:: x3=0 x2=1 x1=1 x0=0 ]   --> x3=0 is padded by cons
	       [:: x2=1 x1=1 x0=0 ]
	   zip ------------------------
	       [:: (x3,x2), (x2,x1), (x1, x0) ]
	   bhead
	       [:: (x2,x1), (x1, x0) ]
	*)
	let xas' := rev (zip xas (behead xas))  in
	let xbs' := rev (zip xbs (behead xbs))  in
	let init := (0, 0, [:: (x0a, x0b)]) in  (* For party A,B: c0=0, y0=x0 *)
	let list_of_pairs := foldl zn_to_z2_folder init (zip sps (zip xas' xbs')) in
	let y_bits := map list_of_pairs in
	let ya_bits := map (fun '(ca, cb, (ya, yb)) => ya) list_of_pairs in
	let yb_bits := map (fun '(ca, cb, (ya, yb)) => yb) list_of_pairs in
	(ya_bits, yb_bits).

(* Alice: 3 = (0 1 1); Bob: 2 = (0 1 0); A+B = 5 = (1 0 1) = zn-to-z2 5*)
(* Need 3 times of SMC scalar-product. *)
Definition demo_Alice3_Bob2_zn_to_z2 : (list Z * list Z) := 
	let sps := [:: 
		preset_sp [::9] [::8] 13 66;
		preset_sp [::32] [::43] 34 5;
		preset_sp [::57] [::40] 31 32
	] in
	let x0a := 1 in
	let x0b := 0 in
	let xas := [:: 0; 1; 1] in
	let xbs := [:: 0; 1; 0] in
	zn_to_z2 sps x0a x0b xas xbs.

Eval compute in (demo_Alice3_Bob2_zn_to_z2).

Lemma demo_smc_Alice3_Bob2_zn_to_z2: fst demo_Alice3_Bob2_zn_to_z2 `+_2 snd demo_Alice3_Bob2_zn_to_z2 = [:: 1; 0; 1].
Proof.
	compute.
	done.
Qed.


(*TODO:


Because SMC ia a general (list Z -> list Z -> (Z * Z)) definition,
any SMC can be the `sp`. We must show what we feed to z2-to-zn, is SMC scalar-product,
so we can use the scalar_product_correct lemma.

----

Learnt:

Need to _bring_ proved properties and functions asssociated to the
new proof goal. For example, in `zn_to_z2_step2_1_correct`, 
the `sp` needs to be exactly the scalar_product function,
so previously proved things about the scalar_product function can be used.

So the proof bring more definitions and parameters than the proof target
function itself. For example, parameters for both scalar_product and zn_to_z2_step2_1
are all listed. Not just paramterrs for the proof target zn_to_z2_step2_1.

It is like proving it works in a context. While the context in this case is
all related parameters. When writing tests, there are some test environments
like mocks or configs, too.

*)

(*Memo:

    let (b, c) := f a in (b, c)

is a syntax sugar of:

    match f a with (b, c) => (b, c) end

This means you need to destruct on f a to finish the proof.

    destruct (f a)

So:

let (tai, tbi) :=
  sp [:: cai; xai; xai] [:: xbi; cbi; xbi] in
tai + tbi = [:: cai; xai; xai] `* [:: xbi; cbi; xbi]

Equals to:

match (sp [:: cai; xai; xai] [:: xbi; cbi; xbi]) with (tai + tbi = [:: cai; xai; xai] `* [:: xbi; cbi; xbi]) => (tai, tbi) end

*)