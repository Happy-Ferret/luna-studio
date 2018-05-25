{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE UndecidableInstances      #-}
{-# EXT      InlineAll                 #-}

module Parser.Pass.Definition where

import Prologue

import qualified Control.Monad.State.Layered            as State
import qualified Data.Graph.Component.Node.Construction as Term
import qualified Luna.IR                                as IR
import qualified Luna.Pass                              as Pass
import qualified Luna.Pass.Attr                         as Attr
import qualified Luna.Pass.Scheduler                    as Scheduler
import qualified Luna.Syntax.Text.Lexer                 as Lexer
import qualified Parser.IR.Class       as Token
import qualified Parser.IR.Term        as Parsing
import qualified Parser.State.Marker   as Marker
import qualified Text.Megaparsec                        as Parser

import Data.Text.Position                          (FileOffset)
import Data.Text32                                 (Text32)
import Luna.Pass                                   (Pass)
import Parser.Data.CodeSpan       (CodeSpan, CodeSpanRange)
import Parser.Data.Invalid        (Invalids)
import Parser.Data.Name.Hardcoded (hardcode)
import Parser.Data.Result         (Result (Result))
import Parser.IR.Class            (Error, ParserBase, Stream,
                                                    Token)
import Parser.Pass.Class          (IRBS, Parser, fromIRBS)
import Parser.State.Indent        (Indent)
import Parser.State.LastOffset    (LastOffset)
import Parser.State.Reserved      (Reserved)
import Luna.Syntax.Text.Scope                      (Scope)
import Luna.Syntax.Text.Source                     (Source)
import Text.Megaparsec                             (ParseError, ParsecT)
import Text.Megaparsec.Error                       (parseErrorPretty)



-------------------------
-- === Parser pass === --
-------------------------

-- === Definition === --

instance Pass.Definition Parser where
    definition = do
        src             <- Attr.get @Source
        (unit, markers) <- runParser__ Parsing.unit (convert src)
        Attr.put $ Result unit


-- === API === --

-- registerStatic :: Registry.Monad m => m ()
-- registerStatic = do
--     Registry.registerPrimLayer @IR.Terms @CodeSpan

registerDynamic :: (Scheduler.PassRegister Parser m, Scheduler.Monad m) => m ()
registerDynamic = do
    Scheduler.registerAttr     @Invalids
    Scheduler.enableAttrByType @Invalids
    Scheduler.registerAttr     @Source
    Scheduler.enableAttrByType @Source
    Scheduler.registerAttr     @Result
    Scheduler.enableAttrByType @Result
    Scheduler.registerPass     @Parser


-- === Internal === --

runParsec__ :: MonadIO m =>
    ParserBase a -> Stream -> m (Either (ParseError Token Error) a)
runParsec__ p s = liftIO $ Parser.runParserT p "" s ; {-# INLINE runParsec__ #-}

runParserContext__ :: MonadIO m =>
    Token.Parser a -> Stream -> m (Either (ParseError Token Error) a)
runParserContext__ p s
    = flip runParsec__ s
    $ State.evalDefT @CodeSpanRange
    $ State.evalDefT @Reserved
    $ State.evalDefT @Scope
    $ State.evalDefT @LastOffset
    $ State.evalDefT @Marker.State
    -- $ State.evalDefT @Position
    $ State.evalDefT @FileOffset
    $ State.evalDefT @Indent
    $ hardcode >> p
{-# INLINE runParserContext__ #-}

runParser__ :: Token.Parser (IRBS a) -> Text32 -> Pass Parser (a, Marker.TermMap)
runParser__ p src = do
    let tokens = Lexer.evalDefLexer src
        parser = Parsing.stx *> p <* Parsing.etx
    runParserContext__ parser tokens >>= \case
        Left e -> error ("Parser error: " <> parseErrorPretty e <> "\ntokens:\n" <> show tokens)
        Right irbs -> do
            ((ref, unmarked), gidMap) <- State.runDefT @Marker.TermMap
                                       $ State.runDefT @Marker.TermOrphanList
                                       $ fromIRBS irbs
            pure (ref, gidMap)
