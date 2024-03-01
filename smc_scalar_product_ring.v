From mathcomp Require Import all_ssreflect all_algebra ring.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Section fintype_extra.
Lemma bump0 n : bump 0 n = n.+1. Proof. by []. Qed.
End fintype_extra.

Section seq_extra.
Lemma rev1 [T : Type] (x : T) : rev [:: x] = [:: x].
Proof. by []. Qed.

(* should be split int size_seq0 and size_seqS *)
Lemma size_seq1 [T : Type] (s : seq T) :
  size s = 1%N -> exists t, s = [:: t].
Proof.
case: s => //= a s.
move/succn_inj/size0nil->.
by exists a.
Qed.

Lemma take_zip (S T : Type) (s : seq S) (t : seq T) n :
  take n (zip s t) = zip (take n s) (take n t).
Proof. by elim: n s t => [|n IH] [|s1 s] [|t1 t] //=; rewrite IH. Qed.

Lemma nth_zip' (S T : Type) (x : S) (y : T) s t i :
  i < minn (size s) (size t) ->
  nth (x, y) (zip s t) i = (nth x s i, nth y t i).
Proof.
move=> ?.
rewrite -(@nth_take (minn (size s) (size t))) //.
rewrite take_zip nth_zip; last first.
  by rewrite !size_take_min minnAC -[RHS]minnA !minnn.
by rewrite !nth_take.
Qed.

Lemma nth_unzip1 (S T : Type) x y (s : seq (S * T)) i :
  nth x (unzip1 s) i = (nth (x,y) s i).1.
Proof.
have /orP [H|?] := leqVgt (size s) i; last by rewrite (nth_map (x,y)).
by rewrite !nth_default ?size_map.
Qed.

Lemma nth_unzip2 (S T : Type) x y (s : seq (S * T)) i :
  nth y (unzip2 s) i = (nth (x,y) s i).2.
Proof.
have /orP [H|?] := leqVgt (size s) i; last by rewrite (nth_map (x,y)).
by rewrite !nth_default ?size_map.
Qed.
End seq_extra.

Import GRing.Theory Num.Theory.

Reserved Notation "la '`*' lb" (at level 40, format "'[' la  `*  lb ']'").
Reserved Notation "la '`+' lb" (at level 50, format "'[' la  `+  lb ']'").

Local Open Scope ring_scope.

Fixpoint zipWith  (A B C: Type) (fn : A -> B -> C) (l1 : list A) (l2 : list B) : list C :=
	match l1, l2 with
	| [::], _ => [::]
	| _, [::] => [::]
	| a1 :: tl1, a2 :: tl2 => fn a1 a2 :: (zipWith fn tl1 tl2)
	end.

Lemma zipWithE (A B : Type) (f : A -> A -> B) (xx yy : list A) :
  zipWith f xx yy = [seq f xy.1 xy.2 | xy <- zip xx yy].
Proof.
move: yy; elim: xx; first by case.
by move=> x xx IH; case=> //= y yy; rewrite IH.
Qed.

Lemma size_zipWith {A B: Type} (fn : A -> A -> B) (l1 : list A) (l2 : list A) :
  size (zipWith fn l1 l2) = minn (size l1) (size l2).
Proof. by rewrite zipWithE size_map size_zip. Qed.

Lemma big_zipWith_cat
  [R : Type] [idx : R] (op : Monoid.com_law idx) [I : Type] (r1 r2 : seq I) 
  (P Q : pred I) (F : I -> R) :
  size [seq i <- r1 | P i] = size [seq i <- r2 | Q i] ->
  \big[op/idx]_(i <- zipWith op [seq F i | i <- r1 & P i] [seq F i | i <- r2 & Q i]) i =
    op (\big[op/idx]_(i <- r1 | P i) F i) (\big[op/idx]_(i <- r2 | Q i) F i).
Proof.
move=> H.
rewrite zipWithE big_map big_split.
rewrite -(big_map fst xpredT idfun) /= -/(unzip1 _) unzip1_zip ?size_map ?H //.
rewrite -(big_map snd xpredT idfun) /= -/(unzip2 _) unzip2_zip ?size_map ?H //.
by rewrite !big_map !big_filter.
Qed.

Arguments big_zipWith_cat [R idx] op [I] r1 r2 P Q F.

Lemma big_zipWith_cat'
  [R : Type] [idx : R] (op : Monoid.com_law idx) (r1 r2 : seq R) :
  size r1 = size r2 ->
  \big[op/idx]_(i <- zipWith op r1 r2) i =
    op (\big[op/idx]_(i <- r1) i) (\big[op/idx]_(i <- r2) i).
Proof.
have:= (big_zipWith_cat op r1 r2 xpredT xpredT idfun).
by rewrite /= !filter_predT !map_id; exact.
Qed.

Arguments big_zipWith_cat' [R idx] op r1 r2.

Lemma zipWithC (A B : Type) (f : A -> A -> B) (aa bb : seq A) :
  (forall a b, f a b = f b a) ->
  zipWith f aa bb = zipWith f bb aa.
Proof.  
move: bb; elim: aa=> //=; first by case.
by move=> a aa IH; case=> //= b bb H; rewrite H (IH _ H).
Qed.
Arguments zipWithC [A B] f.


Section smc_scalar_product.

Variable Z:ringType.

Definition dotproduct (la lb: list Z) : Z :=
	foldl +%R 0 (zipWith *%R la lb).


(*

  The previous version `add`:

    map (fun a => a.1 + a.2) (zip la lb).

  Need extra hypothesis for their length,
  and thus all related proofs need those hypothesis.

  Therefore, we use this fixpoint version to save the extra work.
*)

Fixpoint add (la lb: list Z) : list Z :=
    match la, lb with
    |[::], _ => lb
    |_, [::] => la
    |a::la, b::lb => a+b :: add la lb
    end.

Notation "la '`*' lb" := (dotproduct la lb).
Notation "la '`+' lb" := (add la lb).

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

Definition SMC := list Z -> list Z -> (Z * Z).

Definition is_scalar_product (sp: SMC) :=
  forall(Xa Xb: list Z),
  (sp Xa Xb).1 + (sp Xa Xb).2 = Xa `* Xb.

End smc_scalar_product.

Notation "la '`*' lb" := (dotproduct la lb).
Notation "la '`+' lb" := (add la lb).

(* Note that some rings cannot be computed.
   But this one is okay:
 *)
Eval compute in (demo_Alice3_Bob2 [ringType of int]).

Section smc_scalar_product_facts.

(* to prove, need com *)
Variable R:comRingType.


(*
TODO: Lemma for:
foldl (fun sum : R => [eta +%R sum]) 0 [::] = foldl (fun sum : R => [eta +%R sum]) 0 [::]

BigOp instead of foldling.
*)


Lemma dot_productC (aa bb : list R) : aa `* bb = bb `* aa.
Proof.
rewrite /dotproduct.
elim: aa bb 0 => [| a aa IH] [| b bb] z //=.
by rewrite mulrC.
Qed.

Lemma dot_productE (aa bb: list R) (z: R): z + aa `* bb = foldl +%R z (zipWith *%R aa bb).
Proof.
rewrite /dotproduct -[in RHS](addr0 z).
elim: aa bb z 0=> [| a aa IH] [| b bb] z z2 //=.
by rewrite IH addrA.
Qed.  

Lemma dot_productDr (aa bb cc : list R) :
  aa `* (bb `+ cc) = aa `* bb + aa `* cc.
Proof.
rewrite /dotproduct.
set z:={1 2}0.
rewrite -{1}(addr0 z).
elim: aa bb cc z 0 => [| a aa IH] [| b bb] [|c cc] z z2 //=;
  rewrite ?IH -!dot_productE //=; ring.
Qed.

Lemma scalar_product_correct (Ra Rb : list R) (ra yb : R) :
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

End smc_scalar_product_facts.

Section zn_to_z2.

Let B := bool.

(* vectors of B *)


Definition step2_1 (sp: SMC B) (ci xi: (B * B)) : (B * B) :=
  sp [:: ci.1; xi.1; xi.1] [:: xi.2; ci.2; xi.2].

Definition step2_1_correct (sp: SMC B) (ci xi: B * B) :=
    let alice_input := [:: ci.1; xi.1; xi.1] in
    let bob_input := [:: xi.2; ci.2; xi.2] in
    let t := step2_1 sp ci xi in
    t.1 + t.2 = alice_input `* bob_input .

Lemma step2_1_correctP (sp: SMC B) (ci xi: B * B) :
	is_scalar_product sp ->
        step2_1_correct sp ci xi.
Proof.
move=>Hsp.
rewrite /step2_1_correct.
rewrite /step2_1.
by rewrite Hsp.
Qed.
  
(* Step 2 for two party. *)
Definition step2_2 (ti: B * B) (ci xi xi' : B * B) :
  (B * B) * (B * B) :=
	let cai' := (ci.1 * xi.1 + ti.1) in
	let cbi' := (ci.2 * xi.2 + ti.2) in
	let yai' := (xi'.1 + cai') in
	let ybi' := (xi'.2 + cbi') in
	((cai', cbi'), (yai', ybi')).

Definition step2_2_correct (ti: B * B) (ci xi xi' : B * B) :=
    let (c, y) := step2_2 ti ci xi xi' in
    y.1 = c.1 + xi'.1 /\ y.2 = c.2 + xi'.2.

Lemma step2_2_correctP (ti: B * B) (ci xi xi' : B * B):
    step2_2_correct ti ci xi xi'.
Proof. rewrite /step2_2_correct /=; split; ring. Qed.

Section zn_to_z2_ntuple.

Variable (n: nat) (sps: n.-tuple (SMC B)) (xas xbs: n.+1.-tuple B).


Let W {n} (i : 'I_n) : 'I_n.+1 := widen_ord (@leqnSn _) i.
Let S {n} (i : 'I_n) : 'I_n.+1 := lift ord0 i.
(* Memo: Use Let: things disappear after closing the section. *)

Notation "t '!_' i" := (tnth t i) (at level 10). (* lv9: no parenthesis; so lv10*)

Hypothesis xan : xas!_(ord_max) = false.
Hypothesis xbn : xbs!_(ord_max) = false.
Hypothesis sps_is_sp : forall i, is_scalar_product (sps !_ i).

(*acc: carry-bit Alice, Bob will receive; results Alice, bob will receive*)
Definition zn_to_z2_folder (acc: list ((B * B) * (B * B))) (i: 'I_n):
  list ((B * B) * (B * B)) :=
	let '((ca, cb), _) := head ((0,0),(0,0)) acc in
	let sp := tnth sps i in
	let i_ := W i in (* make it can use the implicit argument *)
	let i' := S i in
	let xa := xas !_ i_ in
	let xa' := xas !_ i' in
	let xb := xbs !_ i_ in
	let xb' := xbs !_ i' in
	step2_2 (step2_1 sp (ca, cb) (xa, xb)) (ca, cb) (xa, xb) (xa', xb') :: acc.

(* xs[0] = lowest bit *)
Definition zn_to_z2 :=
	let init := [:: ((0, 0), (tnth xas 0, tnth xbs 0))] in  (* For party A,B: c0=0, y0=x0 *)
	foldl zn_to_z2_folder init (ord_tuple n). 


(*
Variables i : nat.

Eval unfold is_true in is_true (n-i<n.+1)%N.

``` have Hn:(n-i<n.+1)%N by rewrite subnn. ``
(n-i<n.+1)%N is an element of bool.
Hn is an element of type (n-i<n.+1)%N, more precisely, of type (is_true (n-i<n.+1)%N).

``` Let Hn := (n-i<n.+1)%N ```
Hn is (n-i<n.+1)%N

Lemma ord0_Ordn (i: nat) (Hn : (n-i<n.+1)%N) :
  ord0 = Ordinal Hn.
Proof.
Abort.
*)

(*
Lemma ord_subnn (m0 m1 : nat) (o : 'I_(m0-m1).+1) :
  m0 = m1 -> o = ord0 :> 'I_(m0-m1).+1.
Proof. by move: o=> /[swap] ->; rewrite subnn => o; rewrite ord1. Qed.
Arguments ord_subnn : clear implicits.
*)

(*
usual recursion: use f(n-1) to compute f(n)
inverted recursion: use f(n) to compute f(n-1)

inverted recursion could be formalized for any ordinal o : 'I_n

pose i:=n.
have Hi:(i <= n)%N by [].
have Hn:(n-i<n.+1)%N by rewrite subnn.
have ->: ord0 = Ordinal Hn.
  apply /val_inj.
  by rewrite /= subnn.

This is the preparatory part of the inverted recursion.
 *)

(*acc_correct acc (W i) -> acc_correct (zn_to_z2_folder acc i) (S i).*)
(*We expect the nat in P has the same range of `'I_n.+1`*)
Lemma foldl_ord_tuple (A: Type) (f: A -> 'I_n -> A) (P: A -> nat -> Prop) (init: A) :
  (forall acc (i:'I_n), P acc i -> P (f acc i) i.+1 )->
  P init 0%N -> P (foldl f init (ord_tuple n)) n.
Proof.
move=>H.
pose i:=n.
have Hi:(i <= n)%N by [].
have ->: (0 = n - i)%N by rewrite subnn.
have ->: ord_tuple n = drop (n-i) (ord_tuple n) :> list _.
  by rewrite /= subnn drop0.
elim: i Hi init => [|i IH] Hi init Hinit.
  rewrite /=.
  rewrite subn0 drop_oversize //=.
    by rewrite subn0 in Hinit.
  by rewrite size_enum_ord.
have Hi': (n - i.+1 < n)%N by rewrite (_ : i = Ordinal Hi) // rev_ord_proof.
move /(_ init (Ordinal Hi')) in H.
have Hn': (n - i < n.+1)%N by rewrite ltnS leq_subr.
rewrite (_: (Ordinal Hi').+1 = n - i)%N in H;last first.
  by rewrite /= subnS prednK // subn_gt0.
move:(IH (ltnW Hi) _ (H Hinit)).
suff: drop (n - i.+1) (ord_tuple n) = Ordinal Hi' :: drop (n - i) (ord_tuple n).
  by move ->.
rewrite -{1}(cat_take_drop (n-i.+1) (ord_tuple n)).
rewrite drop_size_cat; last by rewrite size_takel // size_tuple leq_subr.
rewrite (drop_nth (Ordinal Hi')) ?size_tuple //.
rewrite {3}subnS prednK ?subn_gt0 //.
by rewrite {2}(_ : (n-i.+1)%N = Ordinal Hi') // -tnth_nth tnth_ord_tuple.
Qed.

Let Wi {n} {m : 'I_n} : 'I_m -> 'I_n := @widen_ord _ n (ltnW (ltn_ord m)).

Definition carry_correct (ca cb ca' cb' xa xb : B) :=
  ((ca + cb)%R * 2 + (xa + ca' + (xb + cb'))%R = (ca' + cb')%R + (xa + xb))%N.

(* Here we expect `i < n+1` *)
(* Note if the plus is not the correct one, add nat_of_bool function call for %R parts.*)
(* By Print decimal_eq (Set Printing All)*)
Definition decimal_eq (cas cbs yas ybs : list B) (i: nat) :=
  ((cas `_ i + cbs `_ i)%R * 2 ^ i +
   \sum_(j < i) (yas `_ j + ybs `_ j)%R * 2 ^ j == (* `=` means a Prop; `==` means a bool *)
     \sum_(j < i) ((xas `_ j)%R + (xbs `_ j)%R) * 2 ^ j)%N.

(* Here we expect `i < n+1` *)
Definition acc_correct (acc: list ((B * B) * (B * B))) (i: nat) :=
  let acc := rev acc in
  let cas := unzip1 (unzip1 acc) in
  let cbs := unzip2 (unzip1 acc) in
  let yas := unzip1 (unzip2 acc) in
  let ybs := unzip2 (unzip2 acc) in
  [/\ size acc = i.+1,
    [/\ cas`_0 = 0,  (* i.e. cas`_i = 0 *)
      cbs`_0 = 0,
      yas`_i = xas`_i + cas`_i
      & ybs`_i = xbs`_i + cbs`_i]
    & decimal_eq cas cbs yas ybs i].

(*
Definition step2_correct (acc: list ((B * B) * (B * B))) (i: 'I_n) :=
  let cas := unzip1 (unzip1 acc) in
  let cbs := unzip2 (unzip1 acc) in
  let yas := unzip1 (unzip2 acc) in
  let ybs := unzip2 (unzip2 acc) in
  let i_ := W i in
  let sp := sps !_ i in
  let ca := (rev cas) `_ i_ in
  let cb := (rev cbs) `_ i_ in
  let xa := (xas `_ i_) in
  let xb := (xbs `_ i_) in
  acc_correct acc i_ -> @step2_1_correct sp (ca, cb) (xa, xb).
*)
Lemma add_cat (R : ringType) (s1 s2 t1 t2 : seq R) :
  size s1 = size t1 ->
  add (s1 ++ s2) (t1 ++ t2) = add s1 t1 ++ add s2 t2.
Proof. elim: s1 t1 => [|a aa IH] [|b bb] //= [Hs]. by rewrite IH. Qed.

Lemma rev_add (R : ringType) (s t : seq R) :
  size s = size t -> rev (s `+ t) = rev s `+ rev t.
Proof.
rewrite -(revK s) -(revK t) !(size_rev (rev _)).
elim: (rev s) (rev t) => [|a aa IH] [|b bb] //= [Hs].
by rewrite !rev_cons -!cats1 add_cat ?size_rev //= !cats1 !rev_rcons IH.
Qed.

(*
Lemma nth_add' (R : ringType) (s t : seq R) (i : nat) :
  (i < minn (size s) (size t))%N -> (s `+ t) `_ i = s `_ i + t `_ i.
Proof.
move=> ist.
rewrite /add (nth_map (GRing.zero _)); last by rewrite size_zip.
by rewrite nth_zip' //.
Qed.

Lemma nth_add (R : ringType) (s t : seq R) (i : nat) :
  size s = size t -> (s `+ t) `_ i = s `_ i + t `_ i.
Proof.
move=> st.
have /orP [zst|] := leqVgt (size (zip s t)) i; last first.
  by rewrite size_zip; exact: nth_add'.
rewrite !nth_default ?addr0 //.
- by move: zst; rewrite size_zip st minnn.
- by move: zst; rewrite size_zip -st minnn.
- by rewrite size_map.
Qed.
*)

Lemma take1 (s: seq B):
  (size s > 0)%N -> take 1 s = [::head 0 s].
Proof.
by case: s => [| ? []].
Qed.

Lemma carry_correctP  cai_ cbi_ tai_ tbi_ (i : 'I_n) :
  tai_ + tbi_ = [:: cai_; xas`_i; xas`_i] `* [:: xbs`_i; cbi_; xbs`_i] ->
  carry_correct (cai_ * xas`_i + tai_) (cbi_ * xbs`_i + tbi_)
                cai_ cbi_ xas`_i xbs`_i.
Proof.
move => Htai_tbi.
rewrite /carry_correct /=.
rewrite -(addrC tbi_) addrA -(addrA _ tai_) (addrA tai_) {}Htai_tbi.
rewrite /dotproduct /=. (* calc dotproduct*)
by move: cai_ (xas`_i) (xbs`_i) cbi_ => [] [] [] [].
Qed.

Lemma unzip1_rev A C (s : seq (A*C)) : unzip1 (rev s) = rev (unzip1 s).
Proof. exact: map_rev. Qed.

Lemma unzip2_rev A C (s : seq (A*C)) : unzip2 (rev s) = rev (unzip2 s).
Proof. exact: map_rev. Qed.

Lemma zn_to_z2_folder_correct acc i:
  acc_correct acc (W i) -> acc_correct (zn_to_z2_folder acc i) (S i).
Proof.
move=> []. 
move Hacc: acc => [ |[[cai cbi] [ya yb]] acc'] //.
rewrite -Hacc size_rev.
move=> /= Hsz [Hca Hcb Hyas Hybs] Hdec.
rewrite /zn_to_z2_folder {1}Hacc /= !(tnth_nth 0) /= bump0.
have := step2_1_correctP (cai, cbi) (xas`_i, xbs`_i) (sps_is_sp i).
rewrite /step2_1_correct /=. 
case: step2_1 => tai tbi /= Htai_tbi.
rewrite /acc_correct size_rev /= Hsz.
rewrite !(unzip1_rev,unzip2_rev) in Hca Hcb Hyas Hybs Hdec *.
rewrite /step2_2 /=.
split => //.
  by rewrite !rev_cons !nth_rcons !size_rev !size_map Hsz /= ltnn eqxx Hca Hcb.
rewrite /decimal_eq 2!big_ord_recr /=.
rewrite !nth_rev /= ?(size_rev,size_map,Hsz) // !(subnn,subSn) //=.
move/eqP: Hdec => /= <-.
apply/eqP.
under eq_bigr do rewrite !(rev_cons,nth_rcons,size_rev,size_map,Hsz) ltnW ?ltnS //.
rewrite addnA addnAC [RHS]addnAC.
congr addn.
rewrite !nth_rev ?(size_rev,size_map,Hsz) // subnn Hacc /=.
rewrite expnS mulnA -!mulnDl -(carry_correctP Htai_tbi).
congr ((_ + _) * _)%N.
move: Hsz Hyas Hybs; rewrite Hacc /=; clear => /= -[Hsz].
rewrite !rev_cons !nth_rcons !size_rev !size_map Hsz /= ltnn eqxx.
by move => -> ->.
Qed.

Lemma decimal_eq0:
  decimal_eq [:: 0] [:: 0] [:: xas`_0] [:: xbs`_0] 0.
Proof. by rewrite /decimal_eq /= !big_ord0 addn0. Qed.

Lemma zn_to_z2_correct :
  let acc := rev zn_to_z2 in
  let cas := unzip1 (unzip1 acc) in
  let cbs := unzip2 (unzip1 acc) in
  let yas := unzip1 (unzip2 acc) in
  let ybs := unzip2 (unzip2 acc) in
  decimal_eq cas cbs yas ybs n.
Proof.
apply (foldl_ord_tuple zn_to_z2_folder_correct (init:=[:: ((0, 0), (tnth xas 0, tnth xbs 0))])).
Undo 1.
(* Discard all things from let...in *)
have[|_ [] _ [] _ [] _ [] _ //]:= foldl_ord_tuple zn_to_z2_folder_correct (init:=[:: ((0, 0), (tnth xas 0, tnth xbs 0))]).
rewrite /acc_correct /= ?size_tuple //= !(tnth_nth 0) !addr0.
by rewrite decimal_eq0.
Qed.

End zn_to_z2_ntuple.

Section zn_to_z2_demo.

Variable (n: nat) (sps: n.-tuple (SMC B)) (xas xbs: n.+1.-tuple B).

Definition preset_sp (Ra Rb: list B) (ra yb: B): SMC B :=
	scalar_product Ra Rb ra (scalar_product_commidity_rb Ra Rb ra) yb. 

(* Alice: 3 = (1 1 0); Bob: 2 = (0 1 0); A+B = 5 = (1 0 1) = zn-to-z2 5*)
(*             1 2 4             1 2 4              1 2 4*)
(* Need 3 times of SMC scalar-product. *)
Definition demo_Alice3_Bob2_zn_to_z2 : B * B * seq(B * B) := 
	let sps := [tuple
		preset_sp [::9] [::8] 13 66;
		preset_sp [::32] [::43] 34 5;
		preset_sp [::57] [::40] 31 32
	] in
	let xas := [tuple 0; 1; 1; 0] in
	let xbs := [tuple 0; 1; 0; 0] in
	zn_to_z2 sps xas xbs.

(* Note: not computable (show symbols only). *)
Eval compute in (demo_Alice3_Bob2_zn_to_z2).

End zn_to_z2_demo.


(**

About why the `apply` also works in  `zn_to_z2_correct` (not sure yet)

   Our goal is to prove that of `decimal_eq2` holds with a fully accumulated acc after zn_to_z2,
   and we know that how we define `acc_correct` is saying that `acc_correct` implies this `decimal_eq` goal,
   so we use apply to transform the goal from `decimal_eq` to `acc_correct`.

   The term to apply, is `foldl_ord_tuple` which show the implication from `acc_correct` to
   `decimal_eq` with things from `zn_to_z2`??

*)
