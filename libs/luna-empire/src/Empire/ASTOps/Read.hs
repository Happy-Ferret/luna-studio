{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}

{-|

This module consists only of operation that get information from
AST, without modifying it. They can still throw exceptions though.

-}

module Empire.ASTOps.Read where

import           Control.Monad                      ((>=>), (<=<), forM)
import           Control.Monad.Catch                (Handler(..), catches)
import           Data.Maybe                         (isJust)
import           Empire.Prelude
import           Control.Lens                       (preview)
import qualified Safe

import           LunaStudio.Data.Node               (NodeId)
import qualified LunaStudio.Data.PortRef            as PortRef
import           LunaStudio.Data.Port               (OutPortId(..), OutPortIndex(..))
import qualified LunaStudio.Data.NodeLoc            as NodeLoc
import           Empire.ASTOp                       (ClassOp, GraphOp, ASTOp, match)
import           Empire.Data.AST                    (NodeRef, EdgeRef, NotUnifyException(..),
                                                     NotLambdaException(..), PortDoesNotExistException (..),
                                                     astExceptionFromException, astExceptionToException)
import qualified Empire.Data.Graph                  as Graph
import qualified Empire.Data.BreadcrumbHierarchy    as BH
import           Empire.Data.Layers                 (Marker)

import qualified Luna.IR as IR

import qualified System.IO as IO

cutThroughGroups :: GraphOp m => NodeRef -> m NodeRef
cutThroughGroups r = match r $ \case
    Grouped g -> cutThroughGroups =<< source g
    _         -> return r

cutThroughMarked :: ClassOp m => NodeRef -> m NodeRef
cutThroughMarked r = match r $ \case
    Marked m expr -> cutThroughMarked =<< source expr
    _             -> return r

cutThroughDoc :: ClassOp m => NodeRef -> m NodeRef
cutThroughDoc r = match r $ \case
    Documented _d expr -> cutThroughDoc =<< source expr
    _                  -> return r

cutThroughDocAndMarked :: ClassOp m => NodeRef -> m NodeRef
cutThroughDocAndMarked r = match r $ \case
    Marked _m expr  -> cutThroughDocAndMarked =<< source expr
    Documented _d a -> cutThroughDocAndMarked =<< source a
    _               -> return r

isInputSidebar :: GraphOp m => NodeId -> m Bool
isInputSidebar nid = do
    lambda <- use Graph.breadcrumbHierarchy
    return $ lambda ^. BH.portMapping . _1 == nid

getASTOutForPort :: GraphOp m => NodeId -> OutPortId -> m NodeRef
getASTOutForPort nodeId port = do
    isSidebar <- isInputSidebar nodeId
    if isSidebar
      then getLambdaInputForPort port =<< getTargetFromMarked =<< use (Graph.breadcrumbHierarchy . BH.self)
      else getOutputForPort      port =<< getASTVar nodeId

getLambdaInputForPort :: GraphOp m => OutPortId -> NodeRef -> m NodeRef
getLambdaInputForPort []                           lam = throwM $ PortDoesNotExistException []
getLambdaInputForPort portId@(Projection 0 : rest) lam = cutThroughGroups lam >>= flip match `id` \case
    Lam i _             -> getOutputForPort rest =<< source i
    ASGFunction _ as' _ -> do
        as <- ptrListToList as'
        case as of
            (a : _) -> source a
            _       -> throwM $ PortDoesNotExistException portId
    _                  -> throwM $ PortDoesNotExistException portId
getLambdaInputForPort portId@(Projection i : rest) lam = cutThroughGroups lam >>= flip match `id` \case
    Lam _ o             -> getLambdaInputForPort (Projection (i - 1) : rest) =<< source o
    ASGFunction _ as' _ -> do
        as <- ptrListToList as'
        case as ^? ix i of
            Just a -> source a
            _      -> throwM $ PortDoesNotExistException portId
    _                  -> throwM $ PortDoesNotExistException portId

getOutputForPort :: GraphOp m => OutPortId -> NodeRef -> m NodeRef
getOutputForPort []                           ref = cutThroughGroups ref
getOutputForPort portId@(Projection i : rest) ref = cutThroughGroups ref >>= flip match `id` \case
    Cons _ as' -> do
        as <- ptrListToList as'
        case as   ^? ix i of
            Just s -> getOutputForPort rest =<< source s
            _      -> throwM $ PortDoesNotExistException portId 
    List as'   -> do
        as <- ptrListToList as'
        case as ^? ix i of
            Just s -> getOutputForPort rest =<< source s
            _      -> throwM $ PortDoesNotExistException portId 
    Tuple as'  -> do
        as <- ptrListToList as'
        case as ^? ix i of
            Just s -> getOutputForPort rest =<< source s
            _      -> throwM $ PortDoesNotExistException portId 
    _ -> throwM $ PortDoesNotExistException portId

isGraphNode :: GraphOp m => NodeRef -> m Bool
isGraphNode = fmap isJust . getNodeId

getNodeId :: ASTOp g m => NodeRef -> m (Maybe NodeId)
getNodeId node = do
    rootNodeId <- preview (_Just . PortRef.srcNodeLoc) <$> getLayer @Marker node
    varNodeId  <- (getVarNode node >>= getNodeId) `catch` (\(_e :: NotUnifyException) -> return Nothing)
    varsInside <- (getVarsInside =<< getVarNode node) `catch` (\(_e :: NotUnifyException) -> return [])
    varsNodeIds <- mapM getNodeId varsInside
    let leavesNodeId = foldl' (<|>) Nothing varsNodeIds
    return $ rootNodeId <|> varNodeId <|> leavesNodeId

getPatternNames :: GraphOp m => NodeRef -> m [String]
getPatternNames node = match node $ \case
    Var n     -> return [nameToString n]
    Cons _ as' -> do
        as <- ptrListToList as'
        args  <- mapM source as
        names <- mapM getPatternNames args
        return $ concat names
    Blank{}   -> return ["_"]

data NoNameException = NoNameException NodeRef
    deriving Show

instance Exception NoNameException where
    toException = astExceptionToException
    fromException = astExceptionFromException

getVarName' :: ASTOp a m => NodeRef -> m IR.Name
getVarName' node = match node $ \case
    Var n    -> return n
    Cons n _ -> return n
    Blank{}  -> return "_"
    _        -> throwM $ NoNameException node

getVarName :: ASTOp a m => NodeRef -> m String
getVarName = fmap nameToString . getVarName'

getVarsInside :: ASTOp g m => NodeRef -> m [NodeRef]
getVarsInside e = do
    var <- isVar e
    if var then return [e] else concat <$> (mapM (getVarsInside <=< source) =<< inputs e)

rightMatchOperand :: GraphOp m => NodeRef -> m EdgeRef
rightMatchOperand node = match node $ \case
    Unify _ b -> pure $ generalize b
    _         -> throwM $ NotUnifyException node

getTargetNode :: GraphOp m => NodeRef -> m NodeRef
getTargetNode node = rightMatchOperand node >>= source

leftMatchOperand :: ASTOp g m => NodeRef -> m EdgeRef
leftMatchOperand node = match node $ \case
    Unify a _         -> pure $ generalize a
    ASGFunction n _ _ -> pure $ generalize n
    _         -> throwM $ NotUnifyException node

getVarNode :: ASTOp g m => NodeRef -> m NodeRef
getVarNode node = leftMatchOperand node >>= source

data NodeDoesNotExistException = NodeDoesNotExistException NodeId
    deriving Show
instance Exception NodeDoesNotExistException where
    toException = astExceptionToException
    fromException = astExceptionFromException

data MalformedASTRef = MalformedASTRef NodeRef
    deriving Show
instance Exception MalformedASTRef where
    toException = astExceptionToException
    fromException = astExceptionFromException



getASTRef :: GraphOp m => NodeId -> m NodeRef
getASTRef nodeId = preuse (Graph.breadcrumbHierarchy . BH.children . ix nodeId . BH.self) <?!> NodeDoesNotExistException nodeId

getASTPointer :: GraphOp m => NodeId -> m NodeRef
getASTPointer nodeId = do
    marked <- getASTRef nodeId
    match marked $ \case
        Marked _m expr -> source expr
        _                 -> return marked

getCurrentASTPointer :: GraphOp m => m NodeRef
getCurrentASTPointer = do
    ref <- getCurrentASTRef
    match ref $ \case
        Marked _ expr -> source expr
        _                -> return ref

getCurrentASTRef :: GraphOp m => m NodeRef
getCurrentASTRef = use $ Graph.breadcrumbHierarchy . BH.self

-- TODO[MK]: Fail when not marked and unify with getTargetEdge
getTargetFromMarked :: GraphOp m => NodeRef -> m NodeRef
getTargetFromMarked marked = match marked $ \case
    Marked _m expr -> do
        expr' <- source expr
        match expr' $ \case
            Unify l r -> source r
            _            -> return expr'
    _ -> return marked


getVarEdge :: GraphOp m => NodeId -> m EdgeRef
getVarEdge nid = do
    ref <- getASTRef nid
    match ref $ \case
        Marked _m expr -> do
            expr' <- source expr
            match expr' $ \case
                Unify l r -> return $ generalize l
                _            -> throwM $ NotUnifyException expr'
        _ -> throwM $ MalformedASTRef ref

getTargetEdge :: GraphOp m => NodeId -> m EdgeRef
getTargetEdge nid = do
    ref <- getASTRef nid
    match ref $ \case
        Marked _m expr -> do
            expr' <- source expr
            match expr' $ \case
                Unify l r -> return $ generalize r
                _            -> return $ generalize expr
        _ -> throwM $ MalformedASTRef ref

getNameOf :: GraphOp m => NodeRef -> m (Maybe Text)
getNameOf ref = match ref $ \case
    Marked _ e -> getNameOf =<< source e
    Unify  l _ -> getNameOf =<< source l
    Var    n   -> return $ Just $ convert $ convertTo @String n
    _             -> return Nothing

getASTMarkerPosition :: GraphOp m => NodeId -> m NodeRef
getASTMarkerPosition nodeId = do
    ref <- getASTPointer nodeId
    match ref $ \case
        Unify l r -> source l
        _            -> return ref

getMarkerNode :: GraphOp m => NodeRef -> m (Maybe NodeRef)
getMarkerNode ref = match ref $ \case
    Marked m _expr -> Just <$> source m
    _                 -> return Nothing

getASTTarget :: GraphOp m => NodeId -> m NodeRef
getASTTarget nodeId = do
    ref   <- getASTRef nodeId
    getTargetFromMarked ref

getCurrentASTTarget :: GraphOp m => m NodeRef
getCurrentASTTarget = do
    ref <- use $ Graph.breadcrumbHierarchy . BH.self
    getTargetFromMarked ref

getCurrentBody :: GraphOp m => m NodeRef
getCurrentBody = getFirstNonLambdaRef =<< getCurrentASTTarget

getASTVar :: GraphOp m => NodeId -> m NodeRef
getASTVar nodeId = do
    matchNode <- getASTPointer nodeId
    getVarNode matchNode

getCurrentASTVar :: GraphOp m => m NodeRef
getCurrentASTVar = getVarNode =<< getCurrentASTPointer

getSelfNodeRef :: GraphOp m => NodeRef -> m (Maybe NodeRef)
getSelfNodeRef = getSelfNodeRef' False

getSelfNodeRef' :: GraphOp m => Bool -> NodeRef -> m (Maybe NodeRef)
getSelfNodeRef' seenAcc node = match node $ \case
    Acc t _ -> source t >>= getSelfNodeRef' True
    App t _ -> source t >>= getSelfNodeRef' seenAcc
    _       -> return $ if seenAcc then Just node else Nothing

getLambdaBodyRef :: GraphOp m => NodeRef -> m (Maybe NodeRef)
getLambdaBodyRef lam = match lam $ \case
    Lam _ o -> getLambdaBodyRef =<< source o
    _       -> return $ Just lam

getLambdaSeqRef :: GraphOp m => NodeRef -> m (Maybe NodeRef)
getLambdaSeqRef = getLambdaSeqRef' False

getLambdaSeqRef' :: GraphOp m => Bool -> NodeRef -> m (Maybe NodeRef)
getLambdaSeqRef' firstLam node = match node $ \case
    Grouped g  -> source g >>= getLambdaSeqRef' firstLam
    Lam _ next -> do
        nextLam <- source next
        getLambdaSeqRef' True nextLam
    Seq{}     -> if firstLam then return $ Just node else throwM $ NotLambdaException node
    _         -> if firstLam then return Nothing     else throwM $ NotLambdaException node

getLambdaOutputRef :: GraphOp m => NodeRef -> m NodeRef
getLambdaOutputRef node = match node $ \case
    ASGFunction _ _ b -> source b >>= getLambdaOutputRef
    Grouped g         -> source g >>= getLambdaOutputRef
    Lam _ o           -> source o >>= getLambdaOutputRef
    Seq _ r           -> source r >>= getLambdaOutputRef
    Marked _ m        -> source m >>= getLambdaOutputRef
    _                 -> return node

getFirstNonLambdaRef :: GraphOp m => NodeRef -> m NodeRef
getFirstNonLambdaRef ref = do
    link <- getFirstNonLambdaLink ref
    maybe (return ref) (source) link

getFirstNonLambdaLink :: GraphOp m => NodeRef -> m (Maybe EdgeRef)
getFirstNonLambdaLink node = match node $ \case
    ASGFunction _ _ o -> return $ Just $ generalize o
    Grouped g         -> source g >>= getFirstNonLambdaLink
    Lam _ next        -> do
        nextLam <- source next
        match nextLam $ \case
            Lam{} -> getFirstNonLambdaLink nextLam
            _     -> return $ Just $ generalize next
    _         -> return Nothing

isApp :: GraphOp m => NodeRef -> m Bool
-- isApp expr = isJust <$> narrowTerm @IR.App expr
isApp expr = match expr $ \case
    App{} -> return True
    _     -> return False

isBlank :: GraphOp m => NodeRef -> m Bool
-- isBlank expr = isJust <$> narrowTerm @IR.Blank expr
isBlank expr = match expr $ \case
    Blank{} -> return True
    _     -> return False

isLambda :: GraphOp m => NodeRef -> m Bool
isLambda expr = match expr $ \case
    Lam{}     -> return True
    Grouped g -> source g >>= isLambda
    _         -> return False

isEnterable :: GraphOp m => NodeRef -> m Bool
isEnterable expr = match expr $ \case
    Lam{}         -> return True
    ASGFunction{} -> return True
    Grouped g     -> source g >>= isEnterable
    _             -> return False

isMatch :: GraphOp m => NodeRef -> m Bool
-- isMatch expr = isJust <$> narrowTerm @IR.Unify expr
isMatch expr = match expr $ \case
    Unify{} -> return True
    _     -> return False

isCons :: GraphOp m => NodeRef -> m Bool
-- isCons expr = isJust <$> narrowTerm @IR.Cons expr
isCons expr = match expr $ \case
    Cons{} -> return True
    _     -> return False

isVar :: ASTOp a m => NodeRef -> m Bool
-- isVar expr = isJust <$> narrowTerm @IR.Var expr
isVar expr = match expr $ \case
    Var{} -> return True
    _     -> return False

isTuple :: GraphOp m => NodeRef -> m Bool
-- isTuple expr = isJust <$> narrowTerm @IR.Tuple expr
isTuple expr = match expr $ \case
    Tuple{} -> return True
    _     -> return False

isASGFunction :: GraphOp m => NodeRef -> m Bool
-- isASGFunction expr = isJust <$> narrowTerm @IR.Function expr
isASGFunction expr = match expr $ \case
    ASGFunction{} -> return True
    _     -> return False

isAnonymous :: GraphOp m => NodeRef -> m Bool
isAnonymous expr = match expr $ \case
    Marked _ e -> isAnonymous =<< source e
    Unify _ _  -> return False
    _          -> return True

dumpPatternVars :: GraphOp m => NodeRef -> m [NodeRef]
dumpPatternVars ref = match ref $ \case
    Var _     -> return [ref]
    Cons _ as -> fmap concat $ mapM (dumpPatternVars <=< source) =<< ptrListToList as
    Grouped g -> dumpPatternVars =<< source g
    Tuple a   -> fmap concat $ mapM (dumpPatternVars <=< source) =<< ptrListToList a
    _         -> return []

nodeIsPatternMatch :: GraphOp m => NodeId -> m Bool
nodeIsPatternMatch nid = (do
    root <- getASTPointer nid
    varIsPatternMatch root) `catches` [
          Handler (\(e :: NotUnifyException)         -> return False)
        , Handler (\(e :: NodeDoesNotExistException) -> return False)
        ]

varIsPatternMatch :: GraphOp m => NodeRef -> m Bool
varIsPatternMatch expr = do
    var <- getVarNode expr
    not <$> isVar var

rhsIsLambda :: GraphOp m => NodeRef -> m Bool
rhsIsLambda ref = do
    rhs <- getTargetNode ref
    isLambda rhs

canEnterNode :: GraphOp m => NodeRef -> m Bool
canEnterNode ref = do
    match' <- isMatch ref
    if match' then rhsIsLambda ref else return False

classFunctions :: ClassOp m => NodeRef -> m [NodeRef]
classFunctions unit = do
    klass' <- classFromUnit unit
    match klass' $ \case
        ClsASG _ _ _ _ funs'' -> do
            funs <- ptrListToList funs''
            funs' <- mapM source funs
            catMaybes <$> forM funs' (\f -> cutThroughDocAndMarked f >>= \fun -> match fun $ \case
                ASGFunction{} -> return (Just f)
                _             -> return Nothing)

classFromUnit :: ClassOp m => NodeRef -> m NodeRef
classFromUnit unit = match unit $ \case
    Unit _ _ c -> source c

getMetadataRef :: ClassOp m => NodeRef -> m (Maybe NodeRef)
getMetadataRef unit = do
    klass' <- classFromUnit unit
    match klass' $ \case
        ClsASG _ _ _ _ funs'' -> do
            funs <- ptrListToList funs''
            funs' <- mapM source funs
            (Safe.headMay . catMaybes) <$> forM funs' (\f -> match f $ \case
                Metadata{} -> return (Just f)
                _          -> return Nothing)
        _ -> return Nothing

getFunByNodeId :: ClassOp m => NodeId -> m NodeRef
getFunByNodeId nodeId = do
    cls  <- use Graph.clsClass
    funs <- classFunctions cls
    fs   <- forM funs $ \fun -> do
        nid <- getNodeId fun
        return $ if nid == Just nodeId then Just fun else Nothing
    case catMaybes fs of
        []  -> throwM $ NodeDoesNotExistException nodeId
        [f] -> return f
        _   -> error $ "multiple functions with " <> show nodeId
