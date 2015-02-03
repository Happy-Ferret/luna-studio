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

module Luna.Pass.Transform.AST.Desugar.ImplicitSelf.ImplicitSelf where

import           Flowbox.Prelude                               hiding (error, id, mod)
import           Flowbox.System.Log.Logger
import qualified Luna.DEP.AST.Expr                                 as Expr
import           Luna.DEP.AST.Module                               (Module)
import qualified Luna.DEP.AST.Module                               as Module
import qualified Luna.DEP.AST.Pat                                  as Pat
import           Luna.Data.ASTInfo                             (ASTInfo)
import           Luna.Pass.Pass                                (Pass)
import qualified Luna.Pass.Pass                                as Pass
import           Luna.Pass.Transform.AST.Desugar.General.State (DesugarState)
import qualified Luna.Pass.Transform.AST.Desugar.General.State as State



logger :: LoggerIO
logger = getLoggerIO $(moduleName)


type DesugarPass result = Pass DesugarState result


run :: ASTInfo -> Module -> Pass.Result (Module, ASTInfo)
run inf = Pass.run_ (Pass.Info "Desugar.ImplicitSelf") (State.mk inf) . desugar


desugar :: Module -> DesugarPass (Module, ASTInfo)
desugar mod = (,) <$> desugarModule mod <*> State.getInfo


desugarModule :: Module -> DesugarPass Module
desugarModule = Module.traverseM desugarModule desugarExpr pure pure pure pure


desugarExpr :: Expr.Expr -> DesugarPass Expr.Expr
desugarExpr ast = case ast of
    Expr.Function {} -> (\self -> ast & Expr.inputs %~ (self:)) <$> selfArg
                        where selfArg = Expr.Arg <$> State.genID <*> selfPat <*> pure Nothing
                              selfPat = Pat.Var <$> State.genID <*> pure "self"
    _                -> continue
    where continue  = Expr.traverseM desugarExpr pure pure pure pure ast


