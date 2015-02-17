---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

-- FIXME [pm]: [wd] to chyba niepowinien być pass. Funkcje traverse juz mamy. Pogadajmy o tym.

module Luna.DEP.Pass.Analysis.ID.Traverse where

import           Flowbox.Prelude            hiding (mapM, mapM_, op)
import           Luna.DEP.AST.Arg           (Arg)
import           Luna.DEP.AST.Arg           (Arg)
import qualified Luna.DEP.AST.Arg           as Arg
import qualified Luna.DEP.AST.Arg           as Arg
import qualified Luna.DEP.AST.Common        as AST
import           Luna.DEP.AST.Control.Focus (Focus)
import qualified Luna.DEP.AST.Control.Focus as Focus
import           Luna.DEP.AST.Expr          (Expr)
import qualified Luna.DEP.AST.Expr          as Expr
import           Luna.DEP.AST.Lit           (Lit)
import qualified Luna.DEP.AST.Lit           as Lit
import           Luna.DEP.AST.Module        (Module)
import qualified Luna.DEP.AST.Module        as Module
import           Luna.DEP.AST.Pat           (Pat)
import qualified Luna.DEP.AST.Pat           as Pat
import           Luna.DEP.AST.Type          (Type)
import qualified Luna.DEP.AST.Type          as Type



traverseFocus :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Focus -> m ()
traverseFocus op = void . Focus.traverseMR (processModule op) (processExpr op)
     (processType op) (processPat op) (processLit op) (processArg op)


traverseModule :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Module -> m ()
traverseModule op = void . Module.traverseMR (processModule op) (processExpr op)
    (processType op) (processPat op) (processLit op) (processArg op)


traverseExpr :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Expr -> m ()
traverseExpr op = void . Expr.traverseMR (processExpr op) (processType op)
    (processPat op) (processLit op) (processArg op)


traversePat :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Pat -> m ()
traversePat op = void . Pat.traverseMR (processPat op) (processType op) (processLit op)


traverseType :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Type -> m ()
traverseType op = void . Type.traverseMR (processType op)


traverseLit :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Lit -> m ()
traverseLit op l = op $ l ^. Lit.id


processModule :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Module -> m Module
processModule op m = op (m ^. Module.id) >> return m


processExpr :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Expr -> m Expr
processExpr op e = op (e ^. Expr.id) >> return e


processPat :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Pat -> m Pat
processPat op p = op (p ^. Pat.id) >> return p


processType :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Type -> m Type
processType op t = op (t ^. Type.id) >> return t


processLit :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Lit -> m Lit
processLit op l = op (l ^. Lit.id) >> return l


processArg :: (Applicative m, Monad m) => (AST.ID -> m ()) -> Arg a -> m (Arg a)
processArg op a = op (a ^. Arg.id) >> return a
