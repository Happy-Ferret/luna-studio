---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE ConstraintKinds           #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE Rank2Types                #-}
{-# LANGUAGE TemplateHaskell           #-}

module Luna.Pass.Source.File.Writer where

import           Control.Monad.RWS
import qualified System.IO         as IO

import           Flowbox.Prelude                    hiding (error, id)
import qualified Flowbox.System.Directory.Directory as Directory
import           Flowbox.System.Log.Logger
import           Flowbox.System.UniPath             (UniPath)
import qualified Flowbox.System.UniPath             as UniPath
import           Luna.Data.Source                   (Source (Source))
import           Luna.Pass.Pass                     (Pass)
import qualified Luna.Pass.Pass                     as Pass



type FRPass result = Pass Pass.NoState result


logger :: Logger
logger = getLogger $(moduleName)


run :: UniPath -> String -> Source -> Pass.Result ()
run = (Pass.run_ (Pass.Info "FileWriter") Pass.NoState) .:. writeSource


module2path :: [String] -> String -> UniPath
module2path m ext = UniPath.addExtension ext $ UniPath.fromList m


writeSource :: UniPath -> String -> Source -> FRPass ()
writeSource urootpath ext (Source m content) = do
    rootpath <- UniPath.expand urootpath
    let fileName   = UniPath.fromList $ (UniPath.toList rootpath) ++ (UniPath.toList $ module2path m ext)
        folderName = UniPath.basePath fileName
    liftIO $ do Directory.createDirectoryIfMissing True folderName
                IO.writeFile (UniPath.toUnixString fileName) content
