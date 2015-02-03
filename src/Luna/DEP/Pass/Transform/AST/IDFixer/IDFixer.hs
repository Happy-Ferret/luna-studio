---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds  #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE Rank2Types       #-}
{-# LANGUAGE TemplateHaskell  #-}

module Luna.DEP.Pass.Transform.AST.IDFixer.IDFixer where

import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import           Luna.DEP.AST.Arg                          (Arg)
import qualified Luna.DEP.AST.Arg                          as Arg
import qualified Luna.DEP.AST.Common                       as AST
import           Luna.DEP.AST.Control.Focus                (Focus)
import qualified Luna.DEP.AST.Control.Focus                as Focus
import           Luna.DEP.AST.Expr                         (Expr)
import qualified Luna.DEP.AST.Expr                         as Expr
import           Luna.DEP.AST.Lit                          (Lit)
import qualified Luna.DEP.AST.Lit                          as Lit
import           Luna.DEP.AST.Module                       (Module)
import qualified Luna.DEP.AST.Module                       as Module
import           Luna.DEP.AST.Pat                          (Pat)
import qualified Luna.DEP.AST.Pat                          as Pat
import           Luna.DEP.AST.Type                         (Type)
import qualified Luna.DEP.AST.Type                         as Type
import           Luna.DEP.Graph.Node.Expr                  (NodeExpr)
import qualified Luna.DEP.Graph.Node.Expr                  as NodeExpr
import           Luna.DEP.Pass.Pass                        (Pass)
import qualified Luna.DEP.Pass.Pass                        as Pass
import           Luna.DEP.Pass.Transform.AST.IDFixer.State (IDFixerState)
import qualified Luna.DEP.Pass.Transform.AST.IDFixer.State as State



logger :: Logger
logger = getLogger $(moduleName)


type IDFixerPass result = Pass IDFixerState result


runPass :: (Monad m, Functor m)
        => AST.ID -> Maybe AST.ID -> Bool -> Pass.ESRT err Pass.Info IDFixerState m result -> m (Either err result)
runPass maxID rootID fixAll = Pass.run_ (Pass.Info "IDFixer") $ State.make maxID rootID fixAll


run :: AST.ID -> Maybe AST.ID -> Bool -> Focus -> Pass.Result Focus
run maxID rootID fixAll = Pass.run_ (Pass.Info "IDFixer") (State.make maxID rootID fixAll) . fixFocus


runModule :: AST.ID -> Maybe AST.ID -> Bool -> Module -> Pass.Result Module
runModule maxID rootID fixAll = runPass maxID rootID fixAll . fixModule


runExpr :: AST.ID -> Maybe AST.ID -> Bool -> Expr -> Pass.Result Expr
runExpr maxID rootID fixAll = runPass maxID rootID fixAll . fixExpr


runExpr' :: AST.ID -> Maybe AST.ID -> Bool -> Expr -> Pass.Result (Expr, AST.ID)
runExpr' maxID rootID fixAll = runPass maxID rootID fixAll . fixExpr'


runExprs :: AST.ID -> Maybe AST.ID -> Bool -> [Expr] -> Pass.Result [Expr]
runExprs maxID rootID fixAll = runPass maxID rootID fixAll . mapM fixExpr


runType :: AST.ID -> Maybe AST.ID -> Bool -> Type -> Pass.Result Type
runType maxID rootID fixAll = runPass maxID rootID fixAll . fixType


runNodeExpr :: AST.ID -> Maybe AST.ID -> Bool -> NodeExpr -> Pass.Result NodeExpr
runNodeExpr maxID rootID fixAll = runPass maxID rootID fixAll . fixNodeExpr


runNodeExpr' :: AST.ID -> Maybe AST.ID -> Bool -> NodeExpr -> Pass.Result (NodeExpr, AST.ID)
runNodeExpr' maxID rootID fixAll = runPass maxID rootID fixAll . fixNodeExpr'


fixFocus :: Focus -> IDFixerPass Focus
fixFocus = Focus.traverseM fixModule fixExpr


fixModule :: Module -> IDFixerPass Module
fixModule m = do n <- State.fixID $ m ^. Module.id
                 Module.traverseM fixModule fixExpr fixType fixPat fixLit fixArg $ m & Module.id .~ n


fixExpr' :: Expr -> IDFixerPass (Expr, AST.ID)
fixExpr' e = (,) <$> fixExpr e <*> State.getMaxID


fixExpr :: Expr -> IDFixerPass Expr
fixExpr e = do n <- State.fixID $ e ^. Expr.id
               Expr.traverseM fixExpr fixType fixPat fixLit fixArg $ e & Expr.id .~ n


fixPat :: Pat -> IDFixerPass Pat
fixPat p = do n <- State.fixID $ p ^. Pat.id
              Pat.traverseM fixPat fixType fixLit $ p & Pat.id .~ n


fixType :: Type -> IDFixerPass Type
fixType t = do n <- State.fixID $ t ^. Type.id
               Type.traverseM fixType $ t & Type.id .~ n


fixLit :: Lit -> IDFixerPass Lit
fixLit l = do n <- State.fixID $ l ^. Lit.id
              return $ l & Lit.id .~ n


fixArg :: Arg a -> IDFixerPass (Arg a)
fixArg a = do n <- State.fixID $ a ^. Arg.id
              return $ a & Arg.id .~ n


fixNodeExpr :: NodeExpr -> IDFixerPass NodeExpr
fixNodeExpr (NodeExpr.ASTExpr expr) = NodeExpr.ASTExpr <$> fixExpr expr
fixNodeExpr stringExpr              = return stringExpr


fixNodeExpr' :: NodeExpr -> IDFixerPass (NodeExpr, AST.ID)
fixNodeExpr' n = (,) <$> fixNodeExpr n <*> State.getMaxID


clearIDs :: AST.ID -> Module -> Module
clearIDs zero x = runIdentity (Module.traverseMR (return . set Module.id zero)
                                                 (return . set   Expr.id zero)
                                                 (return . set   Type.id zero)
                                                 (return . set    Pat.id zero)
                                                 (return . set    Lit.id zero)
                                                 (return . set    Arg.id zero) x)

clearExprIDs :: AST.ID -> Expr -> Expr
clearExprIDs zero x = runIdentity (Expr.traverseMR (return . set   Expr.id zero)
                                                   (return . set   Type.id zero)
                                                   (return . set    Pat.id zero)
                                                   (return . set    Lit.id zero)
                                                   (return . set    Arg.id zero) x)
