---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# LANGUAGE QuasiQuotes #-}

module Main where

import Text.RawString.QQ
import Text.Show.Pretty

import           Flowbox.Control.Error
import qualified Flowbox.Interpreter.Session.AST.Executor                                as Executor
import qualified Flowbox.Interpreter.Session.Cache.Cache                                 as Cache
import qualified Flowbox.Interpreter.Session.Cache.Invalidate                            as Invalidate
import           Flowbox.Interpreter.Session.Data.DefPoint                               (DefPoint (DefPoint))
import qualified Flowbox.Interpreter.Session.Env                                         as Env
import qualified Flowbox.Interpreter.Session.Error                                       as Error
import qualified Flowbox.Interpreter.Session.Session                                     as Session
import qualified Flowbox.Luna.Data.AST.Crumb.Crumb                                       as Crumb
import           Flowbox.Luna.Data.Pass.Source                                           (Source (Source))
import qualified Flowbox.Luna.Data.PropertyMap                                           as PropertyMap
import           Flowbox.Luna.Lib.LibManager                                             (LibManager)
import qualified Flowbox.Luna.Lib.LibManager                                             as LibManager
import           Flowbox.Luna.Lib.Library                                                (Library (Library))
import qualified Flowbox.Luna.Lib.Library                                                as Library
import qualified Flowbox.Luna.Passes.Analysis.Alias.Alias                                as Analysis.Alias
import qualified Flowbox.Luna.Passes.Analysis.CallGraph.CallGraph                        as Analysis.CallGraph
import qualified Flowbox.Luna.Passes.Transform.AST.DepSort.DepSort                       as Transform.DepSort
import qualified Flowbox.Luna.Passes.Transform.AST.Desugar.ImplicitCalls.ImplicitCalls   as Desugar.ImplicitCalls
import qualified Flowbox.Luna.Passes.Transform.AST.Desugar.ImplicitScopes.ImplicitScopes as Desugar.ImplicitScopes
import qualified Flowbox.Luna.Passes.Transform.AST.Desugar.ImplicitSelf.ImplicitSelf     as Desugar.ImplicitSelf
import qualified Flowbox.Luna.Passes.Transform.AST.Desugar.TLRecUpdt.TLRecUpdt           as Desugar.TLRecUpdt
import qualified Flowbox.Luna.Passes.Transform.AST.TxtParser.TxtParser                   as TxtParser
import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import qualified Flowbox.System.UniPath                                                  as UniPath



rootLogger :: Logger
rootLogger = getLogger "Flowbox"


logger :: LoggerIO
logger = getLoggerIO "Flowbox.Interpreter.Test"


code :: Source
code = Source ["Main"] $ [r|
def test arg arg2:
    print arg
    print arg2
    self.bla "kota" "albo nie"

def bla arg arg2:
    a = "grubego"

    {arg, arg2, print a}

def main:
    a = self.test "ala" "ma"
    print a
    "dummy"
|]

code2 :: Source
code2 = Source ["Main"] $ [r|
def test arg arg2:
    print arg
    print arg2
    self.bla "kota" "albo nie"

def bla arg arg2:
    a = "grubego"

    {arg, arg2, print a}

def main:
    a = self.test "ala2" "ma"
    print a
    "dummy"
|]


readSource :: Source -> IO (LibManager, Library.ID)
readSource source = eitherStringToM' $ runEitherT $ do
    (ast, _, astInfo) <- EitherT $ TxtParser.run source
    (ast, astInfo)    <- EitherT $ Desugar.ImplicitSelf.run astInfo ast
    (ast, astInfo)    <- EitherT $ Desugar.TLRecUpdt.run astInfo ast
    aliasInfo         <- EitherT $ Analysis.Alias.run ast
    callGraph         <- EitherT $ Analysis.CallGraph.run aliasInfo ast
    ast               <- EitherT $ Transform.DepSort.run callGraph aliasInfo ast
    (ast, astInfo)    <- EitherT $ Desugar.ImplicitScopes.run astInfo aliasInfo ast
    (ast, _astInfo)   <- EitherT $ Desugar.ImplicitCalls.run astInfo ast
    _aliasInfo        <- EitherT $ Analysis.Alias.run ast

    let path = UniPath.fromUnixString "."
    return $ LibManager.insNewNode (Library "Main" path ast PropertyMap.empty)
           $ LibManager.empty


main :: IO ()
main = do
    rootLogger setIntLevel 5

    (libManager , libID) <- readSource code
    (libManager2, _    ) <- readSource code2

    let env = Env.mk libManager 0 (DefPoint libID [Crumb.Module "Main", Crumb.Function "main" []])

    putStrLn $ ppShow $ LibManager.lab libManager libID

    result <- Session.run env $ do
        Executor.processMain
        putStrLn "--------- 1"
        Executor.processMain
        putStrLn "========= 1"

        Cache.dumpAll
        Invalidate.modifyNode libID 45
        Cache.dumpAll

        Executor.processMain
        putStrLn "--------- 2"
        Executor.processMain

        putStrLn "========= ready ==========1="
        Cache.dumpAll
        Session.setLibManager libManager2
        Invalidate.modifyNode libID 45
        putStrLn "========= modified =======2="
        Cache.dumpAll
        putStrLn "========= running ========3="
        Executor.processMain
        putStrLn "========= finished =======4="
        Cache.dumpAll
    eitherStringToM $ fmapL Error.format result
