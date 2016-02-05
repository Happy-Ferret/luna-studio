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

module Luna.DEP.Pass.Source.File.Reader where

import           Control.Applicative
import           Control.Monad.RWS
import qualified System.IO                 as IO

import           Data.String.Utils         (replace)
import           Flowbox.Prelude           hiding (error, id)
import           Flowbox.System.UniPath    (UniPath)
import qualified Flowbox.System.UniPath    as UniPath
import           Luna.DEP.Data.Source      (Source (Source))

import           Luna.DEP.Pass.Pass        (Pass)
import qualified Luna.DEP.Pass.Pass        as Pass

import           Flowbox.System.Log.Logger


type FRPass result = Pass Pass.NoState result


logger :: Logger
logger = getLogger $moduleName


run :: UniPath -> UniPath -> Pass.Result Source
run = (Pass.run_ (Pass.Info "FileReader") Pass.NoState) .: readSource


path2module :: UniPath -> [String]
path2module path = UniPath.toList $ UniPath.dropExtension path


getModule :: UniPath -> UniPath -> [String]
getModule rootPath path = path2module $ UniPath.makeRelative rootPath path


readSource :: UniPath -> UniPath -> FRPass Source
readSource rootPath path = do
    filename <- UniPath.toUnixString <$> UniPath.expand path
    txt      <- liftIO $ IO.readFile filename
    let m    = getModule rootPath path
        code = tabs2spaces txt
    return $ Source m code


tabs2spaces :: String -> String
tabs2spaces = replace "\t" "    "
