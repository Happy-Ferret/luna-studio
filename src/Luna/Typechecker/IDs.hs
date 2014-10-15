module Luna.Typechecker.IDs (
    TyID(..), VarID(..)
  ) where



newtype VarID = VarID String
  deriving (Eq,Show,Ord)

newtype TyID = TyID String
  deriving (Eq,Show,Ord)