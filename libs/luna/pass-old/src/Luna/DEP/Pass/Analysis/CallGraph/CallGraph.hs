---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE ConstraintKinds           #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE Rank2Types                #-}
{-# LANGUAGE TemplateHaskell           #-}

module Luna.DEP.Pass.Analysis.CallGraph.CallGraph where

import           Control.Applicative
import           Control.Monad.State                    (get)

import           Flowbox.Prelude                        hiding (error, id, mod)
import           Flowbox.System.Log.Logger
import qualified Luna.DEP.AST.AST                       as AST
import qualified Luna.DEP.AST.Expr                      as Expr
import           Luna.DEP.AST.Module                    (Module)
import qualified Luna.DEP.AST.Module                    as Module
import           Luna.DEP.Data.AliasInfo                (AliasInfo)
import qualified Luna.DEP.Data.AliasInfo                as AliasInfo
import           Luna.DEP.Data.CallGraph                (CallGraph)
import           Luna.DEP.Pass.Analysis.CallGraph.State (State)
import qualified Luna.DEP.Pass.Analysis.CallGraph.State as State
import           Luna.DEP.Pass.Pass                     (Pass)
import qualified Luna.DEP.Pass.Pass                     as Pass



logger :: LoggerIO
logger = getLoggerIO $moduleName


type CGPass result = Pass State result


run :: AliasInfo -> Module -> Pass.Result CallGraph
run info = (Pass.run_ (Pass.Info "CallGraph") $ State.mk info) . cgMod


cgMod :: Module -> CGPass CallGraph
cgMod el@(Module.Module id cls imports classes typeAliases typeDefs fields methods modules) = do
    mapM_ cgRegisterFunc methods
    mapM_ cgExpr methods
    view State.cg <$> get


cgRegisterFunc :: Expr.Expr -> CGPass ()
cgRegisterFunc el@(Expr.Function {}) = State.registerFunction (el ^. Expr.id)


cgExpr :: Expr.Expr -> CGPass ()
cgExpr el = case el of
    Expr.Function   {} -> withID continue
    _                  -> do
                          info <- State.getInfo
                          let mTargetID = info ^. AliasInfo.alias ^. at id
                              mTargetAST = (do tid <- mTargetID; info ^. AliasInfo.ast ^. at tid)
                          case mTargetAST of
                              Nothing  -> return ()
                              Just ast -> case ast of
                                   AST.Expr (func@(Expr.Function {})) -> State.registerCall (func ^. Expr.id)
                                   _                                  -> return ()

                          continue
    where id        = el ^. Expr.id
          withID    = State.withID id
          continue  = Expr.traverseM_ cgExpr pure pure pure pure el


