{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE TupleSections       #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}

module Empire.ASTOps.Builder where

import           Control.Monad                      (foldM, replicateM, zipWithM_)
import           Data.Maybe                         (isNothing)
import qualified Data.Text                          as Text
import           Empire.Prelude
import qualified Safe

import           LunaStudio.Data.Node               (NodeId)
import           LunaStudio.Data.PortRef            (OutPortRefTemplate (..))
import           LunaStudio.Data.NodeLoc            (NodeLoc (..))
import qualified LunaStudio.Data.Port               as Port
import           Empire.ASTOp                       (GraphOp, match)
import           Empire.ASTOps.Deconstruct          (extractAppPorts, deconstructApp, extractFunctionPorts, dumpAccessors)
import           Empire.ASTOps.Remove               (removeSubtree)
import qualified Empire.ASTOps.Read                 as ASTRead
import qualified Empire.ASTOps.Print                as ASTPrint
import qualified Empire.Commands.Code               as Code
import           Empire.Data.AST                    (EdgeRef, NodeRef, astExceptionFromException,
                                                     astExceptionToException)
import           Empire.Data.Layers                 (Marker, SpanLength, SpanOffset)
import qualified Empire.Data.Graph                  as Graph
import qualified Empire.Data.BreadcrumbHierarchy    as BH

import           Data.Text.Position      (Delta)

-- import qualified OCI.IR.Combinators as IR (replace, replaceSource, deleteSubtree)
import qualified Luna.IR as IR


apps :: GraphOp m => Expr f -> [NodeRef] -> m NodeRef
apps fun exprs = unsafeRelayout <$> foldM f (unsafeRelayout fun) (unsafeRelayout <$> exprs)
    where
        f fun' arg' = appAny fun' arg'

appAny :: GraphOp m => NodeRef -> NodeRef -> m NodeRef
appAny = fmap generalize .: IR.app



newApplication :: GraphOp m => NodeRef -> NodeRef -> Int -> m NodeRef
newApplication fun arg' pos = do
    blanks <- sequence $ replicate pos IR.blank
    let args = generalize blanks <> [arg']
    apps fun args

rewireApplication :: GraphOp m => NodeRef -> NodeRef -> Int -> m NodeRef
rewireApplication fun arg' pos = do
    (target, oldArgs) <- deconstructApp fun

    let argsLength = max (pos + 1) (length oldArgs)
    blanks <- replicateM (argsLength - length oldArgs) IR.blank
    let argsCmd = oldArgs <> map generalize blanks
        withNewArg = argsCmd & ix pos .~ arg'

    apps target withNewArg

replaceEdgeSource :: GraphOp m => EdgeRef -> Delta -> NodeRef -> m ()
replaceEdgeSource edge beg newSrc = do
    newCode <- ASTPrint.printFullExpression newSrc
    oldSrc  <- source edge
    oldLen  <- getLayer @SpanLength oldSrc
    Code.applyDiff beg (beg + oldLen) newCode
    replaceSource newSrc $ coerce edge
    deleteSubtree oldSrc
    Code.gossipLengthsChangedBy (fromIntegral (Text.length newCode) - oldLen) =<< target edge

countArguments :: GraphOp m => NodeRef -> m Int
countArguments expr = matchExpr expr $ \case
    Tuple        e   -> return . length =<< ptrListToList e
    App          f _ -> (+ 1) <$> (countArguments =<< source f)
    LeftSection  f _ -> return 2
    RightSection f _ -> return 1
    Grouped      g   -> countArguments =<< source g
    _                -> return 0

getArgumentOf :: GraphOp m => NodeRef -> Delta -> m (EdgeRef, Delta)
getArgumentOf fun beg = matchExpr fun $ \case
    App f a -> do
        off <- Code.getOffsetRelativeToTarget $ coerce a
        return (coerce a, beg + off)
    LeftSection f a -> do
        off <- Code.getOffsetRelativeToTarget $ coerce a
        return (coerce a, beg + off)
    RightSection f a -> do
        off <- Code.getOffsetRelativeToTarget $ coerce a
        return (coerce a, beg + off)
    Grouped g -> do
        off <- Code.getOffsetRelativeToTarget $ coerce g
        g'  <- source g
        getArgumentOf g' (beg + off)
    Tuple l' -> do
        l <- ptrListToList l'
        let t = coerce $ last l
        off <- Code.getOffsetRelativeToTarget t
        return (t, beg + off)
    f -> error $ show f

getOrCreateArgument :: GraphOp m => EdgeRef -> Delta -> Int -> Int -> m (EdgeRef, Delta)
getOrCreateArgument currentFun codeBegin currentArgument neededArgument
    | currentArgument <= neededArgument = do
        padArgs currentFun codeBegin 1 (neededArgument - currentArgument)
        flip getArgumentOf codeBegin =<< source currentFun
    | otherwise = do
        fun <- source currentFun
        matchExpr fun $ \case
            Tuple l' -> do
                l <- ptrListToList l'
                arg  <- return (Safe.atMay l neededArgument) <?!> TupleElementOutOfBoundsException fun neededArgument
                foff <- Code.getOffsetRelativeToTarget $ coerce arg
                return (coerce arg, codeBegin + foff)
            Grouped g -> do
                foff <- Code.getOffsetRelativeToTarget (coerce g)
                getOrCreateArgument (coerce g) (codeBegin + foff) currentArgument neededArgument
            App f a -> do
                foff <- Code.getOffsetRelativeToTarget (coerce f)
                getOrCreateArgument (coerce f) (codeBegin + foff) (pred currentArgument) neededArgument
            LeftSection f a -> do
                foff      <- Code.getOffsetRelativeToTarget (coerce f)
                argOffset <- getLayer @SpanOffset a
                padArgs (coerce f) (codeBegin + foff) argOffset 1
                newFun <- source f
                arg    <- source a
                ap     <- IR.app newFun arg
                putLayer @SpanLength ap =<< getLayer @SpanLength fun
                [f', a'] <- IR.inputs ap
                putLayer @SpanOffset f' =<< getLayer @SpanOffset f
                putLayer @SpanOffset a' =<< getLayer @SpanOffset a
                replace ap fun
                getOrCreateArgument currentFun codeBegin currentArgument neededArgument

data TupleElementOutOfBoundsException = TupleElementOutOfBoundsException NodeRef Int
    deriving Show

instance Exception TupleElementOutOfBoundsException where
    toException = astExceptionToException
    fromException = astExceptionFromException

padArgs :: GraphOp m => EdgeRef -> Delta -> Delta -> Int -> m ()
padArgs e beg argOffset i | i <= 0    = return ()
                          | otherwise = do
    bl     <- IR.blank
    fun    <- source e
    funIsTuple <- ASTRead.isTuple fun
    when funIsTuple $ throwM $ TupleElementOutOfBoundsException fun i
    ap     <- generalize <$> IR.app fun bl
    [f, a] <- IR.inputs ap
    isOp   <- Code.isOperatorVar fun
    funLen <- getLayer @SpanLength fun
    let offset, blankLen :: Num a => a
        offset   = fromIntegral argOffset
        blankLen = 1
    putLayer @SpanLength ap (funLen + offset + blankLen)
    putLayer @SpanLength bl blankLen
    if isOp
        then do
            putLayer @SpanOffset f  offset
            Code.insertAt beg $ Text.cons '_' $ Text.replicate offset " "
        else do
            putLayer @SpanOffset a  offset
            Code.insertAt (beg + funLen) $ Text.snoc (Text.replicate offset " ") '_'
    replaceSource ap $ coerce e
    Code.gossipLengthsChangedBy (offset + blankLen) =<< target e
    padArgs e beg argOffset $ pred i

dropBlankArgumentsAtTailPosition :: GraphOp m => EdgeRef -> Delta -> m ()
dropBlankArgumentsAtTailPosition e beg = do
    head <- source e
    matchExpr head $ \case
        Grouped g -> do
            off <- Code.getOffsetRelativeToTarget (coerce g)
            dropBlankArgumentsAtTailPosition (coerce g) (beg + off)
        App f a -> do
            arg <- source a
            isB <- ASTRead.isBlank arg
            when isB $ do
                fun  <- source f
                argOff    <- Code.getOffsetRelativeToTarget $ coerce a
                argOwnOff <- getLayer @SpanOffset a
                argLen    <- getLayer @SpanLength arg
                funOff    <- getLayer @SpanOffset f
                let toRemoveBegin  = beg + argOff - argOwnOff
                    toRemoveLength = argOwnOff + argLen + funOff
                Code.removeAt toRemoveBegin (toRemoveBegin + toRemoveLength)
                Code.gossipUsesChangedBy (-toRemoveLength) head
                replaceSource fun $ coerce e
                deleteSubtree head
                dropBlankArgumentsAtTailPosition e beg
        _ -> return ()

removeAppArgument :: GraphOp m => EdgeRef -> Delta -> Int -> m ()
removeAppArgument funE beg pos = do
    bl <- generalize <$> IR.blank
    putLayer @SpanLength bl 1
    applyFunction funE beg bl pos
    dropBlankArgumentsAtTailPosition funE beg

removeArgument :: GraphOp m => EdgeRef -> Delta -> Port.InPortId -> m ()
removeArgument funE beg [Port.Self]  = void $ removeAccessor   funE beg
removeArgument funE beg [Port.Arg i] = removeAppArgument funE beg i
removeArgument funE beg (Port.Arg i : rest) = do
    argCount    <- countArguments =<< source funE
    (edge, beg) <- getOrCreateArgument funE beg (argCount - 1) i
    removeArgument edge beg rest
removeArgument funE beg (Port.Self : rest) = do
    (edge, beg) <- getCurrentAccTarget funE beg
    removeArgument edge beg rest
removeArgument _ _ _ = return ()

data SelfPortNotExistantException = SelfPortNotExistantException NodeRef
    deriving (Show)

instance Exception SelfPortNotExistantException where
    toException = astExceptionToException
    fromException = astExceptionFromException

unfoldM :: GraphOp m => (a -> m (Either b a)) -> a -> m b
unfoldM f a = do
    res <- f a
    case res of
        Left  b -> return b
        Right b -> unfoldM f b

unfoldM' :: GraphOp m => (a -> m (Maybe a)) -> a -> m a
unfoldM' f a = do
    res <- f a
    case res of
        Nothing -> return a
        Just a' -> unfoldM' f a'

getCurrentAccTarget :: GraphOp m => EdgeRef -> Delta -> m (EdgeRef, Delta)
getCurrentAccTarget = curry $ unfoldM $ \(edge, codeBeg) -> do
    let passThrough e = Right . (e,) <$> ((+ codeBeg) <$> Code.getOffsetRelativeToTarget e)
    ref <- source edge
    matchExpr ref $ \case
        App f _ -> passThrough $ coerce f
        Acc t _ -> Left . (coerce t,) . (+ codeBeg) <$> Code.getOffsetRelativeToTarget (coerce t)
        _       -> return $ Left (edge, codeBeg)

ensureHasSelf :: GraphOp m => EdgeRef -> Delta -> m ()
ensureHasSelf e beg = source e >>= flip matchExpr `id` \case
    App f _ -> do
        off <- Code.getOffsetRelativeToTarget (coerce f)
        ensureHasSelf (coerce f) $ beg + off
    Acc _ _ -> return ()
    Var n'  -> do
        let n = convertVia @String n'
        bl <- IR.blank
        putLayer @SpanLength bl 1
        ac <- generalize <$> IR.acc bl n'
        putLayer @SpanLength ac (4 + fromIntegral (Text.length n))
        oldTgt <- source e
        replaceSource ac $ coerce e
        deleteSubtree oldTgt
        Code.gossipLengthsChangedBy 4 =<< target e
        Code.insertAt beg "_ . "
        return ()
    LeftSection f a -> do
        bl    <- IR.blank
        putLayer @SpanLength bl 1
        name  <- ASTRead.getVarName =<< source f
        ac    <- IR.acc bl (stringToName name)
        putLayer @SpanLength ac (2 + fromIntegral (length name))
        a'    <- source a
        app   <- generalize <$> IR.app ac a'
        aSpan <- getLayer @SpanLength a'
        putLayer @SpanLength app (2 + fromIntegral (length name) + aSpan)
        oldTarget <- source e
        replaceSource app $ coerce e
        deleteSubtree oldTarget
        Code.insertAt beg "_."
        Code.gossipLengthsChangedBy 2 =<< target e
    _ -> throwM . SelfPortNotExistantException =<< source e

makeAccessor :: GraphOp m => NodeRef -> EdgeRef -> Delta -> m ()
makeAccessor target naming exprBegin = do
    ensureHasSelf naming exprBegin
    (edge, tgtBegin) <- getCurrentAccTarget naming exprBegin
    replaceEdgeSource edge tgtBegin target

applyFunction :: GraphOp m => EdgeRef -> Delta -> NodeRef -> Int -> m ()
applyFunction funE beg arg pos = do
    argCount    <- countArguments =<< source funE
    (edge, beg) <- getOrCreateArgument funE beg (argCount - 1) pos
    replaceEdgeSource edge beg arg

makeConnection :: GraphOp m => EdgeRef -> Delta -> Port.InPortId -> NodeRef -> m ()
makeConnection funE beg [] arg = do
    replaceEdgeSource funE beg arg
makeConnection funE beg (Port.Self : rest) arg = do
    ensureHasSelf funE beg
    (edge, beg) <- getCurrentAccTarget funE beg
    makeConnection edge beg rest arg
makeConnection funE beg (Port.Arg i : rest) arg = do
    argCount <- countArguments =<< source funE
    (edge, beg) <- getOrCreateArgument funE beg (argCount - 1) i
    makeConnection edge beg rest arg
makeConnection _ _ _ _ = return ()


data SelfPortNotConnectedException = SelfPortNotConnectedException NodeRef
    deriving (Show)

instance Exception SelfPortNotConnectedException where
    toException = astExceptionToException
    fromException = astExceptionFromException

removeAccessor :: GraphOp m => EdgeRef -> Delta -> m ()
removeAccessor ed beg = do
    expr <- source ed
    matchExpr expr $ \case
        App f _ -> do
            off <- Code.getOffsetRelativeToTarget $ coerce f
            removeAccessor (coerce f) $ beg + off
        Acc t n -> do
            off <- Code.getOffsetRelativeToTarget $ coerce t
            length <- getLayer @SpanLength expr
            v      <- generalize <$> IR.var n
            let n' = convertVia @String n
            putLayer @SpanLength v $ fromIntegral $ Text.length n'
            Code.applyDiff beg (beg + length) n'
            replaceSource v $ coerce ed
            deleteSubtree expr
            Code.gossipLengthsChangedBy (fromIntegral (Text.length n') - length) =<< target ed
        Grouped g -> do
            off <- Code.getOffsetRelativeToTarget (coerce g)
            removeAccessor (coerce g) (beg + off)
        _ -> return ()

detachNodeMarkers :: GraphOp m => NodeRef -> m ()
detachNodeMarkers ref' = do
    ref <- ASTRead.cutThroughGroups ref'
    putLayer @Marker ref Nothing
    inps <- IR.inputs ref
    mapM_ (source >=> detachNodeMarkers) inps

attachNodeMarkers :: GraphOp m => NodeId -> Port.OutPortId -> NodeRef -> m ()
attachNodeMarkers marker port ref' = go port ref' where
    goOn port args = zipWithM_ go ((port <>) . pure . Port.Projection <$> [0..]) args
    go port ref' = do
        ref <- ASTRead.cutThroughGroups ref'
        match ref $ \case
            Cons _ as -> goOn port =<< mapM source =<< ptrListToList as
            App{}     -> goOn port =<< extractAppPorts ref
            Tuple as  -> goOn port =<< mapM source =<< ptrListToList as
            List  as  -> goOn port =<< mapM source =<< ptrListToList as
            _         -> return () -- putLayer @Marker ref $ Just $ OutPortRef (NodeLoc def marker) port

detachNodeMarkersForArgs :: GraphOp m => NodeRef -> m ()
detachNodeMarkersForArgs lam = do
    args <- extractFunctionPorts lam
    mapM_ detachNodeMarkers args

attachNodeMarkersForArgs :: GraphOp m => NodeId -> Port.OutPortId -> NodeRef -> m ()
attachNodeMarkersForArgs nid port lam = do
    args <- extractFunctionPorts lam
    zipWithM_ (attachNodeMarkers nid) (pure . Port.Projection <$> [0..]) args

data CannotFlipNodeException = CannotFlipNodeException deriving (Show)
instance Exception CannotFlipNodeException where
    toException   = astExceptionToException
    fromException = astExceptionFromException

patternify :: GraphOp m => NodeRef -> m NodeRef
patternify ref = match ref $ \case
    App _ _ -> do
        (fun, args) <- deconstructApp ref
        match fun $ \case
            Cons n _ -> do
                as <- mapM patternify args
                generalize <$> IR.cons n as
            _ -> throwM CannotFlipNodeException
    Var n -> generalize <$> IR.var n -- Copy the Var to forget all metadata like node markers, potentially belonging to other nodes and unified by Alias Analysis
    Grouped g -> patternify =<< source g
    IRNumber{}  -> return ref
    IRString _  -> return ref
    Cons _ _  -> return ref
    _         -> throwM CannotFlipNodeException

appify :: GraphOp m => NodeRef -> m NodeRef
appify ref = match ref $ \case
    Cons n as -> do
        args <- mapM (source >=> appify) =<< ptrListToList as
        fun  <- IR.cons n []
        apps fun args
    Var n     -> generalize <$> IR.var n -- Copy the Var to forget all metadata like node markers, potentially belonging to other nodes and unified by Alias Analysis
    IRNumber{}  -> return ref
    IRString _  -> return ref
    Grouped g -> appify =<< source g
    _         -> throwM CannotFlipNodeException

flipNode :: GraphOp m => NodeId -> m ()
flipNode nid = do
    lhs    <- ASTRead.getASTVar    nid
    rhs    <- ASTRead.getASTTarget nid
    newlhs <- patternify rhs
    newrhs <- appify     lhs
    uni    <- IR.unify newlhs newrhs
    attachNodeMarkers nid [] newlhs
    pointer <- ASTRead.getASTPointer nid
    replace uni pointer

attachName :: GraphOp m => NodeRef -> Text -> m (NodeRef, NodeRef)
attachName node n = do
    var <- IR.var' $ convertVia @String n
    putLayer @SpanLength var (convert $ Text.length n)
    uni    <- IR.unify' var node
    [l, r] <- IR.inputs uni
    putLayer @SpanOffset l 0
    putLayer @SpanOffset r 3
    putLayer @SpanLength uni =<< Code.computeLength uni
    return (var, uni)


ensureNodeHasName :: GraphOp m => (NodeRef -> m Text) -> NodeId -> m ()
ensureNodeHasName generateNodeName nid = do
    ref <- ASTRead.getASTRef nid
    matchExpr ref $ \case
        Marked _ e -> do
            expr  <- source e
            isUni <- ASTRead.isMatch expr
            if isUni then return () else do
                name     <- generateNodeName expr
                (var, uni) <- attachName expr name
                replaceSource uni $ coerce e
                Just codeBeg <- Code.getOffsetRelativeToFile ref
                off          <- Code.getOffsetRelativeToTarget $ coerce e
                Code.insertAt (codeBeg + off) (name <> " = ")
                Code.gossipUsesChangedBy (fromIntegral $ Text.length name + 3) uni
                attachNodeMarkers nid [] var
        _ -> throwM $ ASTRead.MalformedASTRef ref

makeNodeRep :: GraphOp m => NodeId -> Maybe Text -> m Text -> NodeRef -> m (NodeRef, Maybe Text)
makeNodeRep marker name generateNodeName node = do
    (pat, uni, newName) <- match node $ \case
        Unify l r         -> (, node, Nothing) <$> source l
        ASGFunction n a b -> (, node, Nothing) <$> source n
        _                 -> do
            n   <- maybe generateNodeName pure name
            (var, uni) <- attachName node n
            return (var, uni, Just n)
    attachNodeMarkers marker [] pat
    return (uni, newName)
