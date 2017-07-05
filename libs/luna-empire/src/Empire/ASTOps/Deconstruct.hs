{-# LANGUAGE LambdaCase #-}

module Empire.ASTOps.Deconstruct (
    deconstructApp
  , extractArguments
  , extractAppArguments
  , extractLamArguments
  , dumpAccessors
  ) where

import           Empire.Prelude

import           Empire.ASTOp       (GraphOp, match)
import qualified Empire.ASTOps.Read as Read
import           Empire.Data.AST    (NodeRef, NotAppException (..))

import qualified Luna.IR            as IR
import           Luna.IR.Term.Uni


deconstructApp :: GraphOp m => NodeRef -> m (NodeRef, [NodeRef])
deconstructApp app' = match app' $ \case
    Grouped g -> deconstructApp =<< IR.source g
    App a _   -> do
        unpackedArgs <- extractArguments app'
        target       <- extractFun app'
        return (target, unpackedArgs)
    _ -> throwM $ NotAppException app'

extractFun :: GraphOp m => NodeRef -> m NodeRef
extractFun app = match app $ \case
    App a _ -> do
        extractFun =<< IR.source a
    _ -> return app

data ExtractFilter = FApp | FLam

extractArguments :: GraphOp m => NodeRef -> m [NodeRef]
extractArguments expr = match expr $ \case
    App{}       -> reverse <$> extractArguments' FApp expr
    Lam{}       -> extractArguments' FLam expr
    Cons _ args -> mapM IR.source args
    Grouped g   -> IR.source g >>= extractArguments
    _           -> return []

extractLamArguments :: GraphOp m => NodeRef -> m [NodeRef]
extractLamArguments = extractArguments' FLam

extractAppArguments :: GraphOp m => NodeRef -> m [NodeRef]
extractAppArguments = extractArguments' FApp

extractArguments' :: GraphOp m => ExtractFilter -> NodeRef -> m [NodeRef]
extractArguments' FApp expr = match expr $ \case
    App a b -> do
        nextApp <- IR.source a
        args    <- extractArguments' FApp nextApp
        arg'    <- IR.source b
        return $ arg' : args
    Grouped g -> IR.source g >>= extractArguments' FApp
    _       -> return []
extractArguments' FLam expr = match expr $ \case
    Lam b a -> do
        nextLam <- IR.source a
        args    <- extractArguments' FLam nextLam
        arg'    <- IR.source b
        return $ arg' : args
    Grouped g -> IR.source g >>= extractArguments' FLam
    _       -> return []

dumpAccessors :: GraphOp m => NodeRef -> m (Maybe NodeRef, [String])
dumpAccessors = dumpAccessors' True

dumpAccessors' :: GraphOp m => Bool -> NodeRef -> m (Maybe NodeRef, [String])
dumpAccessors' firstApp node = do
    match node $ \case
        Var n -> do
            isNode <- Read.isGraphNode node
            name <- Read.getVarName node
            if isNode
                then return (Just node, [])
                else return (Nothing, [name])
        App t a -> do
            target <- IR.source t
            dumpAccessors' False target
        Acc t n -> do
            target <- IR.source t
            let name = nameToString n
            (tgt, names) <- dumpAccessors' False target
            return (tgt, names ++ [name])
        _ -> return (Just node, [])
