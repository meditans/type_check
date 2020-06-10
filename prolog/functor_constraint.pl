:- module(functor_constraint,[functor_constraint/4]).
:- use_module(library(apply_macros)). % for maplist/*


:- if(current_prolog_flag(dialect, swi)).
:- else.
:- use_module(library(terms)).         % for term_variables/2
:- use_module(library(swi),[put_attr/3]). % for put_attr/3
:- endif.


functor_constraint(Term,Type,Args,ArgTypes) :-
    check_propagator(Term,Type,Args,ArgTypes,Results),
    Results \== [], % no solution
    ( Results = [Result] -> % one solution
        Result = constructor_info(Term,Type,Args,ArgTypes)
    ; % multiple solutions
        term_variables([Type|ArgTypes],SuspensionVars),
        Closure = functor_constraint_reactivation(Term,Type,Args,ArgTypes,_KillFlag),
        suspend_functor_constraint(SuspensionVars,Closure)
    ).

functor_constraint_reactivation(Term,Type,Args,ArgTypes,KillFlag,Var) :-
    ( var(KillFlag) ->
        check_propagator(Term,Type,Args,ArgTypes,Results),
        Results \== [], % no solution
        ( Results = [Result] -> % one solution
            Result = constructor_info(Term,Type,Args,ArgTypes),
            KillFlag = dead
        ; % multiple solutions
            % TODO: narrow possibilities for argument types
            %   using type domain
            ( nonvar(Var) ->
                term_variables(Var,SuspensionVars),
                Closure = functor_constraint_reactivation(Term,Type,Args,ArgTypes,_KillFlag),
                suspend_functor_constraint(SuspensionVars,Closure)
            ;
                true
            )
        )
    ;
        true
    ).

suspend_functor_constraint(Vars,Closure) :-
    maplist(var_suspend_functor_constraint(Closure),Vars).

var_suspend_functor_constraint(Closure,Var) :-
    put_attr(Var,functor_constraint,Closure).

attr_unify_hook(Closure,Term) :-
    call(Closure,Term).

check_propagator(Term,Type,Args,ArgTypes,Results) :-
    copy_term_nat(propagator(Term,Type,Args,ArgTypes),
                  propagator(TermC,TypeC,ArgsC,ArgTypesC)),
    findall(constructor_info(TermC,TypeC,ArgsC,ArgTypesC),type_check:constructor_info(TermC,TypeC,ArgsC,ArgTypesC),Results).
