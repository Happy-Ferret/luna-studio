{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE LambdaCase                #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE TypeApplications          #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE StandaloneDeriving        #-}

module Empire.ASTOps.Parse (
    SomeParserException
  , parseExpr
  , parsePortDefault
  , runParser
  , runFunHackParser
  , runReparser
  , runProperParser
  ) where

import           Data.Convert
import           Empire.Empire
import           Empire.Prelude hiding (mempty)
import           Prologue (convert, convertVia, unwrap', mempty, wrap', wrap)

import           Control.Monad.Catch          (catchAll)
import           Data.Char                    (isUpper)
import           Data.List                    (partition)
import qualified Data.Map                     as Map
import qualified Data.Text                    as Text

import           Empire.ASTOp                    (GraphOp, PMStack, runPass, runPM)
import           Empire.ASTOps.Print
import           Empire.Data.AST                 (NodeRef, astExceptionFromException, astExceptionToException)
import           Empire.Data.Graph               (ClsGraph, Graph)
import qualified Empire.Data.Graph               as Graph (codeMarkers)
import           Empire.Data.Layers              (attachEmpireLayers)
import           Empire.Data.Parser              (ParserPass)

import           LunaStudio.Data.PortDefault     (PortDefault (..), PortValue (..))

import qualified Data.Text.Position              as Pos
import           Data.TypeDesc                   (getTypeDesc)
import qualified Luna.Builtin.Data.Function      as Function (compile, importRooted)
import qualified Luna.IR                         as IR
import qualified Luna.Syntax.Text.Layer.Loc      as Loc
import qualified Luna.Syntax.Text.Parser.CodeSpan as CodeSpan
import           Luna.Syntax.Text.Parser.Errors  (Invalids)
import qualified Luna.Syntax.Text.Parser.Marker  as Parser (MarkedExprMap(..))
import qualified Luna.Syntax.Text.Parser.Parser  as Parser
import qualified Luna.Syntax.Text.Parser.Parsing as Parsing
import qualified Luna.Syntax.Text.Source         as Source
import qualified Luna.IR.Term.Literal            as Lit
import qualified OCI.Pass                        as Pass

data SomeParserException = forall e. Exception e => SomeParserException e

deriving instance Show SomeParserException

instance Exception SomeParserException where
    toException = astExceptionToException
    fromException = astExceptionFromException
    displayException exc = case exc of SomeParserException e -> "SomeParserException (" ++ displayException e ++ ")"

parseExpr :: GraphOp m => String -> m NodeRef
parseExpr s = do
    IR.putAttr @Source.Source $ convert s
    Parsing.parsingPassM Parsing.expr
    res     <- IR.getAttr @Parser.ParsedExpr
    exprMap <- IR.getAttr @Parser.MarkedExprMap
    return $ unwrap' res

parserBoilerplate :: PMStack IO ()
parserBoilerplate = do
    IR.runRegs
    Loc.init
    IR.attachLayer 5 (getTypeDesc @Pos.Range)         (getTypeDesc @IR.AnyExpr)
    CodeSpan.init
    IR.attachLayer 5 (getTypeDesc @CodeSpan.CodeSpan) (getTypeDesc @IR.AnyExpr)
    IR.setAttr (getTypeDesc @Parser.MarkedExprMap)   $ (mempty :: Parser.MarkedExprMap)
    IR.setAttr (getTypeDesc @Parser.ParsedExpr)      $ (error "Data not provided: ParsedExpr")
    IR.setAttr (getTypeDesc @Parser.ReparsingStatus) $ (error "Data not provided: ReparsingStatus")
    IR.setAttr (getTypeDesc @Invalids) $ (mempty :: Invalids)

instance Convertible Text Source.Source where
    convert t = Source.Source (convertVia @String t)

runProperParser :: Text.Text -> IO (NodeRef, IR.Rooted NodeRef, Parser.MarkedExprMap)
runProperParser code = do
    runPM $ do
        parserBoilerplate
        attachEmpireLayers
        -- putStrLn $ Text.unpack code
        IR.setAttr (getTypeDesc @Source.Source) $ (convert code :: Source.Source)
        (unit, root) <- Pass.eval' @ParserPass $ do
            Parsing.parsingPassM Parsing.unit' `catchAll` (\e -> throwM $ SomeParserException e)
            res  <- IR.getAttr @Parser.ParsedExpr
            root <- Function.compile (unwrap' res)
            return (unwrap' res, root)
        Just exprMap <- unsafeCoerce <$> IR.unsafeGetAttr (getTypeDesc @Parser.MarkedExprMap)
        return (unit, root, exprMap)

runParser :: Text.Text -> Command Graph (NodeRef, Parser.MarkedExprMap)
runParser expr = do
    let inits = do
            IR.setAttr (getTypeDesc @Invalids)               $ (mempty :: Invalids)

            IR.setAttr (getTypeDesc @Parser.MarkedExprMap)   $ (mempty :: Parser.MarkedExprMap)
            IR.setAttr (getTypeDesc @Source.Source)          $ (convert expr :: Source.Source)
            IR.setAttr (getTypeDesc @Parser.ParsedExpr)      $ (error "Data not provided: ParsedExpr")
            IR.setAttr (getTypeDesc @Parser.ReparsingStatus) $ (error "Data not provided: ReparsingStatus")
        run = runPass @Graph @ParserPass inits
    run $ do
        Parsing.parsingPassM Parsing.expr `catchAll` (\e -> throwM $ SomeParserException e)
        res     <- IR.getAttr @Parser.ParsedExpr
        exprMap <- IR.getAttr @Parser.MarkedExprMap
        return (unwrap' res, exprMap)

prepareInput :: Text.Text -> Text.Text
prepareInput expr = Text.concat [header, ":\n    None"]
    where
        stripped = Text.strip expr
        header   = case Text.splitOn " " stripped of
            (def:var:args) -> Text.intercalate " " (def:var:args)
            i              -> Text.concat i

runFunHackParser :: Text.Text -> Command ClsGraph (NodeRef, Text.Text)
runFunHackParser expr = do
    let input = prepareInput expr
    parse <- runFunParser input
    return (fst parse, input)

runFunParser :: Text.Text -> Command ClsGraph (NodeRef, Parser.MarkedExprMap)
runFunParser expr = do
    let inits = do
            IR.setAttr (getTypeDesc @Invalids)               $ (mempty :: Invalids)

            IR.setAttr (getTypeDesc @Parser.MarkedExprMap)   $ (mempty :: Parser.MarkedExprMap)
            IR.setAttr (getTypeDesc @Source.Source)          $ (convert expr :: Source.Source)
            IR.setAttr (getTypeDesc @Parser.ParsedExpr)      $ (error "Data not provided: ParsedExpr")
            IR.setAttr (getTypeDesc @Parser.ReparsingStatus) $ (error "Data not provided: ReparsingStatus")
        run = runPass @ClsGraph @ParserPass inits
    run $ do
        Parsing.parsingPassM Parsing.rootedRawFunc `catchAll` (\e -> throwM $ SomeParserException e)
        res     <- IR.getAttr @Parser.ParsedExpr
        exprMap <- IR.getAttr @Parser.MarkedExprMap
        return (unwrap' res, exprMap)

runReparser :: Text.Text -> NodeRef -> Command Graph (NodeRef, Parser.MarkedExprMap, Parser.ReparsingStatus)
runReparser expr oldExpr = do
    let inits = do
            IR.setAttr (getTypeDesc @Invalids)               $ (mempty :: Invalids)

            IR.setAttr (getTypeDesc @Parser.MarkedExprMap)   $ (mempty :: Parser.MarkedExprMap)
            IR.setAttr (getTypeDesc @Source.Source)          $ (convert expr :: Source.Source)
            IR.setAttr (getTypeDesc @Parser.ParsedExpr)      $ (wrap' oldExpr :: Parser.ParsedExpr)
            IR.setAttr (getTypeDesc @Parser.ReparsingStatus) $ (error "Data not provided: ReparsingStatus")
        run = runPass @Graph @ParserPass inits
    run $ do
        do
            gidMapOld <- use Graph.codeMarkers

            -- parsing new file and updating updated analysis
            Parsing.parsingPassM Parsing.valExpr `catchAll` (\e -> throwM $ SomeParserException e)
            gidMap    <- IR.getAttr @Parser.MarkedExprMap

            -- Preparing reparsing status
            rs        <- Parsing.cmpMarkedExprMaps (wrap' gidMapOld) gidMap
            IR.putAttr @Parser.ReparsingStatus (wrap rs)

        res     <- IR.getAttr @Parser.ParsedExpr
        exprMap <- IR.getAttr @Parser.MarkedExprMap
        status  <- IR.getAttr @Parser.ReparsingStatus
        return (unwrap' res, exprMap, status)

data PortDefaultNotConstructibleException = PortDefaultNotConstructibleException PortDefault
    deriving Show

instance Exception PortDefaultNotConstructibleException where
    toException = astExceptionToException
    fromException = astExceptionFromException

parsePortDefault :: GraphOp m => PortDefault -> m NodeRef
parsePortDefault (Expression expr)          = parseExpr expr
parsePortDefault (Constant (IntValue    i)) = IR.generalize <$> IR.number (fromIntegral i)
parsePortDefault (Constant (StringValue s)) = IR.generalize <$> IR.string s
parsePortDefault (Constant (DoubleValue d)) = IR.generalize <$> IR.number (Lit.fromDouble d)
parsePortDefault (Constant (BoolValue   b)) = IR.generalize <$> IR.cons_ (convert $ show b)
parsePortDefault d = throwM $ PortDefaultNotConstructibleException d
