module Luna.Typechecker.Unification (
    mgu
  ) where

import Luna.Typechecker.IDs
import Luna.Typechecker.Substitution
import Luna.Typechecker.TIMonad
import Luna.Typechecker.Type

import Data.Monoid


mgu :: (Monad m) => Type -> Type -> LoggerT String m Subst
mgu (TAp t1 t2) (TAp s1 s2) = do ts1 <- mgu t1 s1
                                 ts2 <- mgu (apply ts1 t2) (apply ts1 s2)
                                 return (ts2 `mappend` ts1)
mgu (TConst a) (TConst b) | a == b = return mempty
mgu (Tvar u) (Tvar v)              = unionConstraints u v
mgu (TVar u)   t                   = varBindRow u t
mgu t var@(TVar u)                 = mgu var t
mgu (TRecord row1) (TRecord row2)  = mgu row1 row2
mgu (TVariant row1) (TVariant ro2) = mgu row1 row2 
mgu (RowEmpty) (RowEmpty)          = return mempty
-- TODO narrowing coercions when row polymorphism won't work
mgu (Row (Row { fName, fType, rowTail1 })) (Row (row2@Row {})) = do
        (fType2, rowTail2, rowInserterS) <- rowInserter row2 (fName, fType)
        fieldSub <- mgu (apply rowInserterS fType) (apply rowInserterS fType2)
        let sub =  fieldSub `mappend` rowInserterS
        subRest <- mgu (apply sub rowTail1) (apply sub rowTail2)
        return $ subRest `mappend` sub
mgu t1 t2 = err "no mgu can be find" ("mgu " ++ show t1 ++ " <> " ++ show t2)

occursCheck u t = u `elem` ftv t

rowInserter EmptyRow (label, fType) = err $ "label " ++ label ++ " connot be inserted"
rowInserter (Row fLabel fType row ) desc@(label, fType)
    | fLabel == label = return (fType, row, mempty)
    | TVar alpha <- row = do
          newRowVar <- mkTyIdWithConstraints (singleConstraint label)
          -- varBindRow will find recursive rows, because of lack constraints
          sub <- varBindRow alpha $ Row label fType newRowVar
          return (fType, apply sub $ Row fLabel fType newRowVar, sub)
    | otherwise = do
          (fieldTy, rowTail, sub) = rowInserter row desc
          return (fieldTy, Row label fieldTy rowTail, sub)

-- | in order to unify two type variables, we must union any lacks constraints
unionConstraints u v
  | u == v    = return nullSubst
  | otherwise =
         let c = (constraint u) `mappend` (constraint v)
         r <- mkTyIdWithConstraints c
         return $ fromMultipleSubstitions [ (u, r), (v, r) ]

-- | If one tries to bind together recursively defined rows, then the
-- intersection of declared methods and constraints won't be empty and it
-- will result in an error
varBindRow u t | t == TVar u     = unionConstraints (TVar u) t -- return mempty
               | occursCheck u t = err "row occurs-check"
               | otherwise       =
    -- check whether t has labels for which u has lack constraints
    case overlappingLabels of 
        [] | Nothing <- rowVariable -> return s1
           | Just r1 <- rowVariable -> do
               -- merge lack constraints
               let newConst = ls `mappend` (constraint r1)
               r2 <- mkTyIdWithConstraints newConst
               let s2 = fromSingleSubstitution (r1, r2)
               return $ s2 `mappend` s1
        labels             -> err $ "repeated label(s): " ++ show labels
    where
      overlappingLabels = S.toList (constraints `S.intersection` definedLabels)
      constraints = constraint u
      (definedLabels, rowVariable) = first getLabels $ typeToTypeList t
      s1 = fromSingleSubstitution (u, t)
      getLabels = S.fromList . map (\(fLabel, fType) -> fLabel)
