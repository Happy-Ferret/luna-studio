---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}

module Flowbox.FileManager.RPC.Handler.File where

import           Flowbox.Bus.RPC.RPC                                        (RPC)
import           Flowbox.Data.Convert
import           Flowbox.FileManager.FileManager                            (FileManager)
import qualified Flowbox.FileManager.FileManager                            as FileManager
import           Flowbox.Prelude                                            hiding (Context)
import           Flowbox.System.Log.Logger
import qualified Generated.Proto.FileManager.FileSystem.File.Copy.Request   as Copy
import qualified Generated.Proto.FileManager.FileSystem.File.Copy.Update    as Copy
import qualified Generated.Proto.FileManager.FileSystem.File.Exists.Request as Exists
import qualified Generated.Proto.FileManager.FileSystem.File.Exists.Status  as Exists
import qualified Generated.Proto.FileManager.FileSystem.File.Fetch.Request  as Fetch
import qualified Generated.Proto.FileManager.FileSystem.File.Fetch.Status   as Fetch
import qualified Generated.Proto.FileManager.FileSystem.File.Move.Request   as Move
import qualified Generated.Proto.FileManager.FileSystem.File.Move.Update    as Move
import qualified Generated.Proto.FileManager.FileSystem.File.Remove.Request as Remove
import qualified Generated.Proto.FileManager.FileSystem.File.Remove.Update  as Remove
import qualified Generated.Proto.FileManager.FileSystem.File.Upload.Request as Upload
import qualified Generated.Proto.FileManager.FileSystem.File.Upload.Status  as Upload



logger :: LoggerIO
logger = getLoggerIO $(moduleName)

------ public api -------------------------------------------------


upload :: FileManager fm ctx => fm
       -> Upload.Request -> RPC ctx IO Upload.Status
upload fm request@(Upload.Request tpath) = do
    let path = decodeP tpath
    FileManager.uploadFile fm path
    return $ Upload.Status request


fetch :: FileManager fm ctx => fm
      -> Fetch.Request -> RPC ctx IO Fetch.Status
fetch fm request@(Fetch.Request tpath) = do
    let path = decodeP tpath
    FileManager.fetchFile fm path
    return $ Fetch.Status request


exists :: FileManager fm ctx => fm
       -> Exists.Request -> RPC ctx IO Exists.Status
exists fm request@(Exists.Request tpath) = do
    let path = decodeP tpath
    e <- FileManager.fileExists fm path
    return $ Exists.Status request e


remove :: FileManager fm ctx => fm
       -> Remove.Request -> RPC ctx IO Remove.Update
remove fm request@(Remove.Request tpath) = do
    let path = decodeP tpath
    FileManager.removeFile fm path
    return $ Remove.Update request


copy :: FileManager fm ctx => fm
     -> Copy.Request -> RPC ctx IO Copy.Update
copy fm request@(Copy.Request tsrc tdst) = do
    let src = decodeP tsrc
        dst = decodeP tdst
    FileManager.copyFile fm src dst
    return $ Copy.Update request


move :: FileManager fm ctx => fm
     -> Move.Request -> RPC ctx IO Move.Update
move fm request@(Move.Request tsrc tdst) = do
    let src = decodeP tsrc
        dst = decodeP tdst
    FileManager.moveFile fm src dst
    return $ Move.Update request
