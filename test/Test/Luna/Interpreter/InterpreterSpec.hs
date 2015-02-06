---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Test.Luna.Interpreter.InterpreterSpec where

import Control.Monad.State hiding (mapM, mapM_)
import Test.Hspec

import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import qualified Luna.DEP.Lib.Lib                                  as Library
import qualified Luna.Interpreter.Session.AST.Executor             as Executor
import qualified Luna.Interpreter.Session.AST.Traverse             as Traverse
import qualified Luna.Interpreter.Session.Data.CallDataPath        as CallDataPath
import           Luna.Interpreter.Session.Data.CallPoint           (CallPoint (CallPoint))
import           Luna.Interpreter.Session.Data.CallPointPath       (CallPointPath)
import qualified Luna.Interpreter.Session.Env                      as Env
import           Luna.Interpreter.Session.Memory.Manager.NoManager (NoManager (NoManager))
import           Luna.Interpreter.Session.Session                  (Session)
import qualified Test.Luna.Interpreter.Common                      as Common
import qualified Test.Luna.Interpreter.SampleCodes                 as SampleCodes


rootLogger :: Logger
rootLogger = getLogger ""


getArgs :: CallPointPath -> Session mm [CallPointPath]
getArgs callPointPath = do
    mainPtr      <- Env.getMainPtr
    testCallData <- CallDataPath.fromCallPointPath callPointPath mainPtr
    args         <- Traverse.arguments testCallData
    return $ map CallDataPath.toCallPointPath args


getSuccessors :: CallPointPath -> Session mm [CallPointPath]
getSuccessors callPointPath = do
    mainPtr      <- Env.getMainPtr
    testCallData <- CallDataPath.fromCallPointPath callPointPath mainPtr
    successors   <- Traverse.next testCallData
    return $ map CallDataPath.toCallPointPath successors


main :: IO ()
main = do rootLogger setIntLevel 5
          hspec spec


shouldBe' :: (Show a, Eq a, MonadIO m) => a -> a -> m ()
shouldBe' = liftIO .: shouldBe

shouldMatchList' :: (Show a, Eq a, MonadIO m) => [a] -> [a] -> m ()
shouldMatchList' = liftIO .: shouldMatchList


spec :: Spec
spec = do
    let mm = NoManager
    describe "AST traverse" $ do
        it "finds function arguments" $ do
            rootLogger setIntLevel 5
            Common.runSession mm SampleCodes.traverseExample $ do
                let lib1      = Library.ID 1
                    var_a     = [CallPoint lib1 22]
                    var_b     = [CallPoint lib1 26]
                    var_c     = [CallPoint lib1 38]
                    fooCall   = [CallPoint lib1 31]
                    var_e     = [CallPoint lib1 31, CallPoint lib1 55]
                    var_n     = [CallPoint lib1 31, CallPoint lib1 59]
                    var_d     = [CallPoint lib1 31, CallPoint lib1 71]
                    barCall   = [CallPoint lib1 31, CallPoint lib1 62]
                    conMain   = [CallPoint lib1 31, CallPoint lib1 62, CallPoint lib1 122]
                    testCall  = [CallPoint lib1 31, CallPoint lib1 62, CallPoint lib1 90]
                    tuple     = [CallPoint lib1 31, CallPoint lib1 62, CallPoint lib1 (-86)]
                    conMain2  = [CallPoint lib1 120]
                    printCall = [CallPoint lib1 41]
                getArgs var_a     >>= shouldBe' []
                getArgs var_b     >>= shouldBe' []
                getArgs var_c     >>= shouldBe' []
                getArgs var_d     >>= shouldBe' []
                getArgs var_e     >>= shouldBe' []
                getArgs var_n     >>= shouldBe' []
                getArgs conMain   >>= shouldBe' []
                getArgs testCall  >>= shouldBe' [conMain, var_c, var_d, var_a, var_b, var_e]
                getArgs tuple     >>= shouldBe' [var_e, var_d, var_c, var_b, testCall, var_a]
                getArgs fooCall   >>= shouldBe' [var_a, var_b, var_c]
                getArgs barCall   >>= shouldBe' [var_a, var_b, var_c, var_d, var_e]
                getArgs conMain2  >>= shouldBe' []
                getArgs printCall >>= shouldBe' [conMain2, fooCall]

        it "finds node successors" $ do
            --putStrLn =<< ppShow <$> Common.readCode SampleCodes.traverseExample
            Common.runSession mm SampleCodes.traverseExample $ do
                let lib1      = Library.ID 1
                    var_a     = [CallPoint lib1 22]
                    var_b     = [CallPoint lib1 26]
                    var_c     = [CallPoint lib1 38]
                    fooCall   = [CallPoint lib1 31]
                    var_e     = [CallPoint lib1 31, CallPoint lib1 55]
                    var_n     = [CallPoint lib1 31, CallPoint lib1 59]
                    var_d     = [CallPoint lib1 31, CallPoint lib1 71]
                    barCall   = [CallPoint lib1 31, CallPoint lib1 62]
                    conMain   = [CallPoint lib1 31, CallPoint lib1 62, CallPoint lib1 122]
                    testCall  = [CallPoint lib1 31, CallPoint lib1 62, CallPoint lib1 90]
                    tuple     = [CallPoint lib1 31, CallPoint lib1 62, CallPoint lib1 (-86)]
                    conMain2  = [CallPoint lib1 120]
                    printCall = [CallPoint lib1 41]
                getSuccessors var_a     >>= shouldMatchList' [var_b, barCall]
                getSuccessors var_b     >>= shouldMatchList' [var_c, barCall]
                getSuccessors var_c     >>= shouldMatchList' [var_e, barCall]
                getSuccessors var_e     >>= shouldMatchList' [var_n, barCall]
                getSuccessors var_n     >>= shouldMatchList' [var_d]
                getSuccessors var_d     >>= shouldMatchList' [conMain, barCall]
                getSuccessors conMain   >>= shouldMatchList' [testCall]
                getSuccessors testCall  >>= shouldMatchList' [barCall]
                getSuccessors tuple     >>= shouldMatchList' [barCall]
                getSuccessors barCall   >>= shouldMatchList' [fooCall]
                getSuccessors fooCall   >>= shouldMatchList' [conMain2]
                getSuccessors conMain2  >>= shouldMatchList' [printCall]
                getSuccessors printCall >>= shouldMatchList' [[]]

    describe "interpreter" $ do
        mapM_ (\(name, code) -> it ("executes example - " ++ name) $ do
            --rootLogger setIntLevel 5
            Common.runSession mm code Executor.processMain_) SampleCodes.sampleCodes

        mapM_ (\(name, code) -> it ("executes example 5 times - " ++ name) $ do
            --rootLogger setIntLevel 5
            Common.runSession mm code $ replicateM_ 5 Executor.processMain_) $ SampleCodes.sampleCodes
