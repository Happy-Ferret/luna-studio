---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}

module Flowbox.Luna.Passes.Transform.Graph.Builder.Builder where

import           Control.Applicative                                 
import           Control.Monad.State                                 
import qualified Data.List as List

import           Flowbox.Prelude                                   hiding (error, mapM, mapM_)
import           Flowbox.Luna.Data.AliasAnalysis                     (AA)
import qualified Flowbox.Luna.Data.AST.Expr                        as Expr
import           Flowbox.Luna.Data.AST.Expr                          (Expr)
import qualified Flowbox.Luna.Data.AST.Lit                         as Lit
import           Flowbox.Luna.Data.AST.Lit                           (Lit)
import qualified Flowbox.Luna.Data.AST.Pat                         as Pat
import           Flowbox.Luna.Data.AST.Pat                           (Pat)
import qualified Flowbox.Luna.Data.AST.Utils                       as AST
import           Flowbox.Luna.Data.Graph.Graph                       (Graph)
import qualified Flowbox.Luna.Data.Graph.Graph                     as Graph
import qualified Flowbox.Luna.Data.Graph.Node                      as Node
import qualified Flowbox.Luna.Data.Graph.Port                      as Port
import qualified Flowbox.Luna.Data.Graph.Properties                as Properties
import qualified Flowbox.Luna.Passes.Pass                          as Pass
import           Flowbox.Luna.Passes.Pass                            (PassMonad)
import qualified Flowbox.Luna.Passes.Transform.Graph.Builder.State as State
import           Flowbox.Luna.Passes.Transform.Graph.Builder.State   (GBState)
import           Flowbox.System.Log.Logger                           



logger :: Logger
logger = getLogger "Flowbox.Luna.Passes.Transform.Graph.Builder.Builder"


type GBMonad m = PassMonad GBState m


run :: PassMonad s m => AA -> Expr -> Pass.Result m Graph
run aa = (Pass.run_ (Pass.Info "GraphBuilder") $ State.make aa) . expr2graph


expr2graph :: GBMonad m => Expr -> Pass.Result m Graph
expr2graph expr = case expr of
    Expr.Function _ _ _ inputs _ body -> do parseArgs inputs
                                            mapM_ buildNode body
                                            State.getGraph
    _                                 -> fail "expr2graph: Unsupported Expr type"


parseArgs :: GBMonad m => [Expr] -> Pass.Result m ()
parseArgs inputs = do
    let numberedInputs = zip inputs [0..]
    mapM_ parseArg numberedInputs


parseArg :: GBMonad m => (Expr, Int) -> Pass.Result m ()
parseArg (input, no) = case input of
    Expr.Arg _ pat _ -> do ([p], _) <- buildPat pat
                           State.addToNodeMap p (Graph.inputsID, Port.Num no)
    _                -> fail "parseArg: Wrong Expr type"


buildNode :: GBMonad m => Expr -> Pass.Result m AST.ID
buildNode expr = case expr of
    Expr.Accessor   i name dst -> do dstID  <- buildNode dst
                                     let node = Node.Expr name (dummyGenName name) dummyProperties 
                                     State.addNode i Port.All node
                                     State.connectAST dstID i 0
                                     return i
    Expr.Assignment i pat dst  -> do (patIDs, patStr) <- buildPat pat
                                     let node = Node.Expr ('=': patStr) (dummyGenName patStr) dummyProperties
                                     State.insNode (i, node)
                                     case patIDs of 
                                        [patID] -> State.addToNodeMap patID (i, Port.All)
                                        _       -> mapM_ (\(n, patID) -> State.addToNodeMap patID (i, Port.Num n)) $ zip [0..] patIDs
                                     dstID <- buildNode dst
                                     State.connectAST dstID i 0
                                     return dummyValue
    Expr.App        i src args -> do srcID       <- buildNode src
                                     (srcNID, _) <- State.aaNodeMapLookUp srcID
                                     argIDs      <- mapM buildNode args
                                     let numberedArgIDs = zip [1..] argIDs
                                     mapM_ (\(no, argID) -> State.connectAST argID srcNID no) numberedArgIDs
                                     return srcID
    Expr.Infix  i name src dst -> do srcID    <- buildNode src
                                     dstID    <- buildNode dst
                                     let node = Node.Expr name (dummyGenName name) dummyProperties
                                     State.addNode i Port.All node
                                     State.connectAST srcID i 0
                                     State.connectAST dstID i 1
                                     return i
    Expr.Var        i _        -> do return i
    Expr.Con        i name     -> do let node = Node.Expr name (dummyGenName name) dummyProperties
                                     State.addNode i Port.All node
                                     return i
    Expr.Lit        i lvalue   -> do (_, litStr) <- buildLit lvalue
                                     let node = Node.Expr litStr (dummyGenName litStr) dummyProperties
                                     State.addNode i Port.All node
                                     return i

dummyGenName :: String -> String
dummyGenName name = "out_" ++ name


--connect :: GBMonad m => Node.ID -> (InPort, ([AST.ID], Maybe String)) -> Pass.Result m ()
--connect dstNID (dstPort, (srcIDs, mname)) = case srcIDs of
--    [] -> do name <- mname <?> "GraphBuilder: Could not connect!"
--             State.addNodeDefault dstPort name dstNID 
--    _  -> do srcIDsP <- mapM State.aaNodeMapLookUp srcIDs
--             mapM_ (\(srcNID, p) -> State.connect srcNID dstNID $ Edge p dstPort) srcIDsP




--buildExpr :: GBMonad m => Expr -> Pass.Result m ([AST.ID], Maybe String)
--buildExpr expr = case expr of
--    Expr.Accessor   i name dst -> do (dstIDs, mdstStr) <- buildExpr dst
--                                     return $ case mdstStr of
--                                                Nothing -> (dstIDs, Just name)
--                                                Just n  -> (dstIDs, Just $ n ++ "." ++ name)
--    Expr.Var        i _        -> do return ([i], Nothing)
--    ----Expr.Assignment i pat dst  -> do (patIDs, patStr) <- buildPat pat
--    ----                                 dstID <- buildExpr dst
--    ----                                 (dstNID, dstPort) <- State.aaNodeMapLookUp dstID
--    ----                                 patNID <- State.insNewNode $ Node.Expr ('=': patStr) (Just expr) dummyProperties
--    ----                                 case patIDs of 
--    ----                                    [patID] -> State.addToMap patID (patNID, Nothing)
--    ----                                    _       -> mapM_ (\(n, patID) -> State.addToMap patID (patNID, Just n)) $ zip [0..] patIDs
--    ----                                 State.connect dstNID patNID $ Edge dstPort 0
--    ----                                 return dummyValue
--    ----Expr.App        i src args -> do srcID <- buildExpr src
--    ----                                 (srcNID, _) <- State.aaNodeMapLookUp srcID
--    ----                                 argIDs <- mapM buildExpr args
--    ----                                 argNIDsP <- mapM State.aaNodeMapLookUp argIDs
--    ----                                 let numberedArgNIDsP = zip [1..] argNIDsP
--    ----                                 mapM_ (\(no, (argNID, p)) -> State.connect argNID srcNID $ Edge p no) numberedArgNIDsP
--    ----                                 return srcID
--    ----Expr.Infix  i name src dst -> do srcID <- buildExpr src
--    ----                                 dstID <- buildExpr dst
--    ----                                 (srcNID, srcP) <- State.aaNodeMapLookUp srcID
--    ----                                 (dstNID, dstP) <- State.aaNodeMapLookUp dstID
--    ----                                 infixNID <- State.addNode i Nothing $ Node.Expr name (Just expr) dummyProperties
--    ----                                 State.connect srcNID infixNID $ Edge srcP 0
--    ----                                 State.connect dstNID infixNID $ Edge dstP 1
--    ----                                 return i
--    Expr.Con        i name     -> do return ([], Just name)
--    Expr.Lit        i lvalue   -> do (_, litStr) <- buildLit lvalue
--                                     return ([], Just litStr)



buildPat :: GBMonad m => Pat -> Pass.Result m ([AST.ID], String)
buildPat pat = case pat of
    Pat.Var      i name     -> return ([i], name)
    Pat.Lit      i value    -> do (litID, litStr) <- buildLit value
                                  return ([i], litStr)
    Pat.Tuple    i items    -> do itemsStr <- mapM buildPat items
                                  let ids  = List.concat $ map fst itemsStr
                                      strs = map snd itemsStr
                                  return (ids, "{" ++ (List.intercalate ", " strs) ++ "}")
    Pat.Con      i name     -> return ([i], name)
    Pat.App      i src args -> do argsStr <- mapM buildPat args
                                  let ids  = List.concat $ map fst argsStr
                                      strs = map snd argsStr
                                  (srcID, srcStr) <- buildPat src
                                  return (ids, srcStr ++ " " ++ (List.intercalate " " strs))
    Pat.Typed    i pat cls  -> do (patIDs, patStr) <- buildPat pat
                                  return $ (patIDs, patStr ++ " :: " ++ dummyString "pattern_Typed")
    Pat.Wildcard i          -> return ([i], "_")


buildLit :: GBMonad m => Lit -> Pass.Result m (AST.ID, String)
buildLit lit = pure $ case lit of 
    Lit.Char    i char -> (i, [char])
    Lit.String  i str  -> (i, str)
    Lit.Integer i str  -> (i, str)
    Lit.Float   i str  -> (i, str)


-- REMOVE ME --
dummyValue = (-1)
dummyProperties = Properties.empty
dummyString s = "dummy_" ++ s
--------------